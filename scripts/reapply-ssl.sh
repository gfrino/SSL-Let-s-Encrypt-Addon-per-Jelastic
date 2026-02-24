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

if [ -f "/var/www/conf/httpd_config.xml" ]; then
  LSWS_CONF="/var/www/conf/httpd_config.xml"
elif [ -f "/usr/local/lsws/conf/httpd_config.xml" ]; then
  LSWS_CONF="/usr/local/lsws/conf/httpd_config.xml"
else
  echo "[ERROR] Config LiteSpeed XML non trovata"
  exit 1
fi

# Trova tutti i domini con certificati Let's Encrypt
DOMAINS=()
if [ -d "/etc/letsencrypt/live" ]; then
  for d in /etc/letsencrypt/live/*/; do
    domain=$(basename "$d")
    [ "$domain" = "README" ] && continue
    [ -f "/etc/letsencrypt/live/$domain/fullchain.pem" ] && DOMAINS+=("$domain")
  done
fi

if [ ${#DOMAINS[@]} -eq 0 ]; then
  echo "[WARN] Nessun certificato Let's Encrypt trovato"
  exit 0
fi

echo "[INFO] Certificati trovati: ${DOMAINS[*]}"

for domain in "${DOMAINS[@]}"; do
  echo "[INFO] Riapplico SNI cert per $domain"

  LSWS_CONF_PATH="$LSWS_CONF" DOMAIN_NAME="$domain" python3 - <<'PY'
import os
import re
from pathlib import Path

conf_path = Path(os.environ["LSWS_CONF_PATH"])
domain = os.environ["DOMAIN_NAME"]
text = conf_path.read_text()

key_file = f"/etc/letsencrypt/live/{domain}/privkey.pem"
cert_file = f"/etc/letsencrypt/live/{domain}/fullchain.pem"
cert_entry = f"<cert><keyFile>{key_file}</keyFile><certFile>{cert_file}</certFile><CA></CA></cert>"

def add_sni_cert_to_listener(xml, address):
    listener_pattern = r"(<listener>.*?<address>" + re.escape(address) + r"</address>.*?</listener>)"
    m = re.search(listener_pattern, xml, flags=re.S)
    if not m:
        print(f"[WARN] Listener {address} non trovato, salto")
        return xml
    block = m.group(1)
    if key_file in block:
        print(f"[INFO] SNI cert già presente per {address}")
        return xml
    if "<certList>" in block:
        new_block = block.replace("</certList>", cert_entry + "</certList>")
    else:
        new_block = block.replace("</listener>", f"<certList>{cert_entry}</certList></listener>")
    return xml[:m.start()] + new_block + xml[m.end():]

for addr in ["*:443", "[::]:443"]:
    text = add_sni_cert_to_listener(text, addr)

conf_path.write_text(text)
print(f"[INFO] Aggiornato {conf_path} per {domain}")
PY

done

sudo su -c "systemctl restart lshttpd" 2>/dev/null || systemctl restart lshttpd 2>/dev/null || true
echo "[OK] Configurazione SSL riapplicata per: ${DOMAINS[*]}"
