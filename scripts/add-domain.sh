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
TEMPLATE_FILE="${TEMPLATE_FILE:-templates/litespeed-vhost.conf}"

LSWS_CONF=""
LSWS_CONF_FORMAT=""
if [ -f "/var/www/conf/httpd_config.conf" ]; then
  LSWS_CONF="/var/www/conf/httpd_config.conf"
  LSWS_CONF_FORMAT="conf"
elif [ -f "/usr/local/lsws/conf/httpd_config.conf" ]; then
  LSWS_CONF="/usr/local/lsws/conf/httpd_config.conf"
  LSWS_CONF_FORMAT="conf"
elif [ -f "/var/www/conf/httpd_config.xml" ]; then
  LSWS_CONF="/var/www/conf/httpd_config.xml"
  LSWS_CONF_FORMAT="xml"
elif [ -f "/usr/local/lsws/conf/httpd_config.xml" ]; then
  LSWS_CONF="/usr/local/lsws/conf/httpd_config.xml"
  LSWS_CONF_FORMAT="xml"
else
  echo "[ERROR] Config LiteSpeed non trovata (httpd_config.conf/xml)"
  exit 1
fi

if [ ! -f "$TEMPLATE_FILE" ]; then
  echo "[ERROR] Template non trovato: $TEMPLATE_FILE"
  exit 1
fi

DOMAINS=$(echo "$RAW_DOMAINS" | tr ',;' '  ' | xargs)
if [ -z "$DOMAINS" ]; then
  echo "[ERROR] Nessun dominio valido"
  exit 1
fi

NEED_RESTART=0

update_conf_conf() {
  local domain="$1"

  if ! grep -q "^virtualhost[[:space:]]\+$domain\b" "$LSWS_CONF"; then
    cat >> "$LSWS_CONF" <<EOF

virtualhost $domain {
  vhRoot                  /var/www
  configFile              /var/www/conf/vhosts/$domain/vhconf.conf
  allowSymbolLink         1
  enableScript            1
  restrained              1
}
EOF
  fi

  local tmp
  tmp="$(mktemp)"
  awk -v domain="$domain" '
    BEGIN {in_listener=0; has_map=0}
    /^listener[ \t]+/ {in_listener=1; has_map=0}
    in_listener && $1=="map" && $2==domain {has_map=1}
    in_listener && /^[ \t]*}/ {
      if (!has_map) print "  map                    " domain " " domain
      print $0
      in_listener=0; has_map=0
      next
    }
    in_listener && /^[ \t]*}/ {in_listener=0; has_map=0}
    {print}
  ' "$LSWS_CONF" > "$tmp" && mv "$tmp" "$LSWS_CONF"
}

update_conf_xml() {
  local domain="$1"

  LSWS_CONF_PATH="$LSWS_CONF" DOMAIN_NAME="$domain" python3 - <<'PY'
import os
import re
from pathlib import Path

conf_path = Path(os.environ["LSWS_CONF_PATH"])
domain = os.environ["DOMAIN_NAME"]

text = conf_path.read_text()

vh_block = (
    "<virtualHost>"
    f"<name>{domain}</name>"
    "<vhRoot>/var/www</vhRoot>"
    f"<configFile>/var/www/conf/vhosts/{domain}/vhconf.conf</configFile>"
    "<allowSymbolLink>1</allowSymbolLink>"
    "<enableScript>1</enableScript>"
    "<restrained>1</restrained>"
    "<setUIDMode>0</setUIDMode>"
    "<chrootMode>0</chrootMode>"
    "</virtualHost>"
)

if f"<name>{domain}</name>" not in text:
    text, count = re.subn(
        r"(<virtualHostList>)(.*?)(</virtualHostList>)",
        r"\1\2" + vh_block + r"\3",
        text,
        count=1,
        flags=re.S,
    )
    if count == 0:
        raise SystemExit("[ERROR] virtualHostList non trovato nel file XML")

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
        print(f"[WARN] Listener {address} non trovato nel file XML, salto")
    return new_xml

def add_sni_cert_to_listener(xml, address):
    """Aggiunge il cert del dominio alla certList del listener HTTPS per SNI."""
    key_file = f"/etc/letsencrypt/live/{domain}/privkey.pem"
    cert_file = f"/etc/letsencrypt/live/{domain}/fullchain.pem"
    cert_entry = f"<cert><keyFile>{key_file}</keyFile><certFile>{cert_file}</certFile><CA></CA></cert>"

    # Trova il listener con questo address e modifica il suo blocco <ssl>
    pattern = (
        r"(<listener>)(.*?<address>" + re.escape(address) + r"</address>.*?)(<ssl>)(.*?)(</ssl>)(.*?</listener>)"
    )

    def repl_ssl(match):
        ssl_content = match.group(4)
        if key_file in ssl_content:
            return match.group(0)  # già presente
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
print(f"[INFO] Aggiornato {conf_path}")
PY
}

for domain in $DOMAINS; do
  if [ -z "$domain" ]; then
    continue
  fi

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

  mkdir -p "$VHOST_DIR"

  cat > "$VHOST_CONF" <<EOF
$(sed "s|{DOMAIN}|$domain|g" "$TEMPLATE_FILE")
EOF

  if [ "$LSWS_CONF_FORMAT" = "conf" ]; then
    update_conf_conf "$domain"
  else
    update_conf_xml "$domain"
    NEED_RESTART=1
  fi

done

if [ "$LSWS_CONF_FORMAT" = "xml" ] && [ "$NEED_RESTART" -eq 1 ]; then
  systemctl restart lsws
else
  systemctl reload lsws
fi

echo "[OK] Domini configurati con SSL"
