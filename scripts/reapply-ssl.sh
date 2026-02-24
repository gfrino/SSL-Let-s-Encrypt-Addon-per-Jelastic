#!/bin/bash
set -e

LOG_FILE="/var/log/wp-multisite-ssl-manager.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "[INFO] Avvio reapply-ssl"
echo "[INFO] User: $(id -u) ($(id -un))"

if [ "$(id -u)" -ne 0 ]; then
  echo "[ERROR] Questo script deve essere eseguito come root"
  exit 1
fi

VHOSTS_DIR="/var/www/conf/vhosts"
LSWS_CONF=""

if [ -f "/var/www/conf/httpd_config.xml" ]; then
  LSWS_CONF="/var/www/conf/httpd_config.xml"
elif [ -f "/usr/local/lsws/conf/httpd_config.xml" ]; then
  LSWS_CONF="/usr/local/lsws/conf/httpd_config.xml"
else
  echo "[ERROR] Config LiteSpeed XML non trovata"
  exit 1
fi

DOMAINS=()
if [ -d "$VHOSTS_DIR" ]; then
  for d in "$VHOSTS_DIR"/*/; do
    domain=$(basename "$d")
    [ "$domain" = "*" ] && continue
    [ -f "/etc/letsencrypt/live/$domain/fullchain.pem" ] && DOMAINS+=("$domain")
  done
fi

if [ ${#DOMAINS[@]} -eq 0 ]; then
  echo "[WARN] Nessun dominio con certificato Let's Encrypt trovato"
  exit 0
fi

echo "[INFO] Domini trovati: ${DOMAINS[*]}"

for domain in "${DOMAINS[@]}"; do
  echo "[INFO] Riapplico SSL per $domain"

  LSWS_CONF_PATH="$LSWS_CONF" DOMAIN_NAME="$domain" python3 - <<'PY'
import os
import re
from pathlib import Path

conf_path = Path(os.environ["LSWS_CONF_PATH"])
domain = os.environ["DOMAIN_NAME"]

text = conf_path.read_text()

# --- vhostMap nei listener ---
def add_map_to_listener(xml, address):
    pattern = (
        r"(<listener>.*?<address>" + re.escape(address) + r"</address>.*?<vhostMapList>)(.*?)(</vhostMapList>)"
    )
    def repl(match):
        body = match.group(2)
        if f"<domain>{domain}</domain>" in body:
            return match.group(0)
        map_block = f"<vhostMap><vhost>{domain}</vhost><domain>{domain}</domain></vhostMap>"
        return match.group(1) + body + map_block + match.group(3)
    new_xml, count = re.subn(pattern, repl, xml, count=1, flags=re.S)
    if count == 0:
        print(f"[WARN] Listener {address} non trovato, salto")
    return new_xml

# --- SNI cert nei listener HTTPS ---
def add_sni_cert_to_listener(xml, address):
    key_file = f"/etc/letsencrypt/live/{domain}/privkey.pem"
    cert_file = f"/etc/letsencrypt/live/{domain}/fullchain.pem"
    cert_entry = f"<cert><keyFile>{key_file}</keyFile><certFile>{cert_file}</certFile><CA></CA></cert>"

    pattern = (
        r"(<listener>)(.*?<address>" + re.escape(address) + r"</address>.*?)(<ssl>)(.*?)(</ssl>)(.*?</listener>)"
    )

    def repl_ssl(match):
        ssl_content = match.group(4)
        if key_file in ssl_content:
            return match.group(0)
        if "<certList>" in ssl_content:
            ssl_content = ssl_content.replace("</certList>", cert_entry + "</certList>")
        else:
            ssl_content += f"<certList>{cert_entry}</certList>"
        return match.group(1) + match.group(2) + match.group(3) + ssl_content + match.group(5) + match.group(6)

    new_xml, count = re.subn(pattern, repl_ssl, xml, count=1, flags=re.S)
    if count == 0:
        print(f"[WARN] Listener HTTPS {address} senza blocco ssl, salto SNI cert")
    return new_xml

for addr in ["*:80", "[::]:80", "*:443", "[::]:443"]:
    text = add_map_to_listener(text, addr)

for addr in ["*:443", "[::]:443"]:
    text = add_sni_cert_to_listener(text, addr)

conf_path.write_text(text)
print(f"[INFO] Aggiornato {conf_path} per {domain}")
PY

done

systemctl restart lsws
echo "[OK] Configurazione SSL riapplicata per: ${DOMAINS[*]}"
