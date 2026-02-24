#!/bin/bash
set -e

LOG_FILE="/var/log/wp-multisite-ssl-manager.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "[INFO] Avvio remove-domain"
echo "[INFO] User: $(id -u) ($(id -un))"

if [ "$(id -u)" -ne 0 ]; then
  echo "[ERROR] Questo script deve essere eseguito come root"
  exit 1
fi

RAW_DOMAINS="$1"
if [ -z "$RAW_DOMAINS" ]; then
  echo "[ERROR] Parametro mancante: domain"
  exit 1
fi

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

DOMAINS=$(echo "$RAW_DOMAINS" | tr ',;' '  ' | xargs)
if [ -z "$DOMAINS" ]; then
  echo "[ERROR] Nessun dominio valido"
  exit 1
fi

NEED_RESTART=0

remove_conf_conf() {
  local domain="$1"
  local tmp
  tmp="$(mktemp)"
  awk -v domain="$domain" '
    BEGIN {skip=0}
    $1=="virtualhost" && $2==domain {skip=1; next}
    skip && /^[ \t]*}/ {skip=0; next}
    skip {next}
    $1=="map" && $2==domain {next}
    {print}
  ' "$LSWS_CONF" > "$tmp" && mv "$tmp" "$LSWS_CONF"
}

remove_conf_xml() {
  local domain="$1"
  LSWS_CONF_PATH="$LSWS_CONF" DOMAIN_NAME="$domain" python3 - <<'PY'
import os
import re
from pathlib import Path

conf_path = Path(os.environ["LSWS_CONF_PATH"])
domain = os.environ["DOMAIN_NAME"]

text = conf_path.read_text()

text = re.sub(
    r"<virtualHost>.*?<name>" + re.escape(domain) + r"</name>.*?</virtualHost>",
    "",
    text,
    flags=re.S,
)

text = re.sub(
    r"<vhostMap>.*?<domain>" + re.escape(domain) + r"</domain>.*?</vhostMap>",
    "",
    text,
    flags=re.S,
)

# Rimuove la SNI cert del dominio da tutti i listener HTTPS
text = re.sub(
    r"<cert><keyFile>/etc/letsencrypt/live/" + re.escape(domain) + r"/privkey\.pem</keyFile>.*?</cert>",
    "",
    text,
    flags=re.S,
)

# Rimuove certList vuote rimaste
text = re.sub(r"<certList>\s*</certList>", "", text, flags=re.S)

conf_path.write_text(text)
print(f"[INFO] Aggiornato {conf_path}")
PY
}

for domain in $DOMAINS; do
  if [ -z "$domain" ]; then
    continue
  fi

  echo "[INFO] Rimuovo dominio $domain"

  if command -v certbot >/dev/null 2>&1; then
    certbot delete --cert-name "$domain" --non-interactive || true
  fi

  rm -rf "/etc/letsencrypt/live/$domain" \
         "/etc/letsencrypt/archive/$domain" \
         "/etc/letsencrypt/renewal/$domain.conf" || true

  rm -rf "/var/www/conf/vhosts/$domain" || true

  if [ "$LSWS_CONF_FORMAT" = "conf" ]; then
    remove_conf_conf "$domain"
  else
    remove_conf_xml "$domain"
    NEED_RESTART=1
  fi

done

if [ "$LSWS_CONF_FORMAT" = "xml" ] && [ "$NEED_RESTART" -eq 1 ]; then
  systemctl restart lsws
else
  systemctl reload lsws
fi

echo "[OK] Domini rimossi"
