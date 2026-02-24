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

remove_sni_cert() {
  local domain="$1"
  LSWS_CONF_PATH="$LSWS_CONF" DOMAIN_NAME="$domain" python3 - <<'PY'
import os
import re
from pathlib import Path

conf_path = Path(os.environ["LSWS_CONF_PATH"])
domain = os.environ["DOMAIN_NAME"]
text = conf_path.read_text()

# Rimuove la SNI cert del dominio dai listener HTTPS
text = re.sub(
    r"<cert><keyFile>/etc/letsencrypt/live/" + re.escape(domain) + r"/privkey\.pem</keyFile>.*?</cert>",
    "",
    text,
    flags=re.S,
)

# Rimuove certList vuote
text = re.sub(r"<certList>\s*</certList>", "", text, flags=re.S)

conf_path.write_text(text)
print(f"[INFO] SNI cert rimossa per {domain}")
PY
}

for domain in $DOMAINS; do
  [ -z "$domain" ] && continue

  echo "[INFO] Rimuovo dominio $domain"

  if command -v certbot >/dev/null 2>&1; then
    certbot delete --cert-name "$domain" --non-interactive || true
  fi

  rm -rf "/etc/letsencrypt/live/$domain" \
         "/etc/letsencrypt/archive/$domain" \
         "/etc/letsencrypt/renewal/$domain.conf" || true

  remove_sni_cert "$domain"

done

sudo su -c "systemctl restart lshttpd" 2>/dev/null || systemctl restart lshttpd 2>/dev/null || true

echo "[OK] Dominio/i rimossi"

echo "[OK] Domini rimossi"
