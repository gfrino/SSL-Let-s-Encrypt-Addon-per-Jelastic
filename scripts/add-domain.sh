#!/bin/bash
set -e

LOG_FILE="/var/log/wp-multisite-ssl-manager.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "[INFO] Avvio add-domain"
echo "[INFO] User: $(id -u) ($(id -un))"

if [ "$(id -u)" -ne 0 ]; then
  echo "[ERROR] Questo script deve essere eseguito come root"
  exit 1
fi

RAW_DOMAINS="$1"
EMAIL="$2"

if [ -z "$RAW_DOMAINS" ] || [ -z "$EMAIL" ]; then
  echo "[ERROR] Parametri mancanti: domain/email"
  exit 1
fi

DOCROOT="/var/www/webroot/ROOT"

if [ -f "/var/www/conf/httpd_config.xml" ]; then
  LSWS_CONF="/var/www/conf/httpd_config.xml"
elif [ -f "/usr/local/lsws/conf/httpd_config.xml" ]; then
  LSWS_CONF="/usr/local/lsws/conf/httpd_config.xml"
else
  echo "[ERROR] Config LiteSpeed XML non trovata"
  exit 1
fi

DOMAINS=$(echo "$RAW_DOMAINS" | tr ',;' '  ' | xargs)
if [ -z "$DOMAINS" ]; then
  echo "[ERROR] Nessun dominio valido"
  exit 1
fi

add_sni_cert() {
  local domain="$1"
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
print(f"[INFO] SNI cert aggiunta per {domain}")
PY
}

for domain in $DOMAINS; do
  [ -z "$domain" ] && continue

  echo "[INFO] Aggiungo dominio $domain"

  certbot certonly \
    --webroot \
    -w "$DOCROOT" \
    -d "$domain" \
    --cert-name "$domain" \
    --email "$EMAIL" \
    --agree-tos \
    --non-interactive

  VHOST_DIR="/var/www/conf/vhosts/$domain"
  VHOST_CONF="$VHOST_DIR/vhconf.conf"
  
  echo "[INFO] Creo vHost per $domain in $VHOST_CONF"
  mkdir -p "$VHOST_DIR"
  
  TEMPLATE_URL="https://raw.githubusercontent.com/gfrino/SSL-Let-s-Encrypt-Addon-per-Jelastic/master/templates/litespeed-vhost.conf"
  echo "[INFO] Scarico template vHost da GitHub"
  curl -fsSL "$TEMPLATE_URL" | sed "s/{DOMAIN}/$domain/g" > "$VHOST_CONF"
  
  if [ ! -s "$VHOST_CONF" ]; then
    echo "[ERROR] Errore creazione vHost conf"
    exit 1
  fi
  
  echo "[INFO] vHost conf creato: $VHOST_CONF"

  add_sni_cert "$domain"
  
  echo "[INFO] Aggiungo vHost $domain alla config XML"
  LSWS_CONF_PATH="$LSWS_CONF" DOMAIN_NAME="$domain" VHOST_CONF_PATH="$VHOST_CONF" python3 - <<'PYVHOST'
import os
import re
from pathlib import Path

conf_path = Path(os.environ["LSWS_CONF_PATH"])
domain = os.environ["DOMAIN_NAME"]
vhost_conf = os.environ["VHOST_CONF_PATH"]
text = conf_path.read_text()

vhost_entry = f"""
  <virtualHost>
    <name>{domain}</name>
    <vhRoot>/var/www/conf/vhosts/{domain}</vhRoot>
    <configFile>{vhost_conf}</configFile>
    <allowSymbolLink>1</allowSymbolLink>
    <enableScript>1</enableScript>
    <restrained>1</restrained>
    <setUIDMode>2</setUIDMode>
  </virtualHost>"""

if f"<name>{domain}</name>" in text:
    print(f"[INFO] vHost {domain} già presente in XML")
else:
    if "<virtualHostList>" in text:
        text = text.replace("</virtualHostList>", vhost_entry + "\n</virtualHostList>")
    else:
        text = text.replace("</httpServerConfig>", f"<virtualHostList>{vhost_entry}\n</virtualHostList>\n</httpServerConfig>")
    conf_path.write_text(text)
    print(f"[INFO] vHost {domain} aggiunto a XML")

# Add vHost mapping to listeners
for addr in ["*:443 SSL", "*:80"]:
    listener_pattern = r"(<listener>.*?<name>" + re.escape(addr.split()[0]) + r"</name>.*?</listener>)"
    m = re.search(listener_pattern, text, flags=re.S)
    if not m:
        continue
    block = m.group(1)
    mapping = f"<map><virtualHost>{domain}</virtualHost><domains>{domain}</domains></map>"
    if f"<virtualHost>{domain}</virtualHost>" in block:
        print(f"[INFO] Mapping {domain} già presente in listener {addr}")
        continue
    if "<vhostMapList>" in block:
        new_block = block.replace("</vhostMapList>", mapping + "</vhostMapList>")
    else:
        new_block = block.replace("</listener>", f"<vhostMapList>{mapping}</vhostMapList></listener>")
    text = text[:m.start()] + new_block + text[m.end():]
    print(f"[INFO] Mapping {domain} aggiunto a listener {addr}")

conf_path.write_text(text)
PYVHOST

done

sudo su -c "systemctl restart lshttpd" 2>/dev/null || systemctl restart lshttpd 2>/dev/null || true

echo "[OK] Domini configurati con SSL"
