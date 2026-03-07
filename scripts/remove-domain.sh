#!/bin/bash
set -e

LOG_FILE="/var/log/wp-multisite-ssl-manager.log"
exec > >(tee -a "$LOG_FILE") 2>&1

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "[INFO] Avvio remove-domain"
log "[INFO] User: $(id -u) ($(id -un))"

if [ "$(id -u)" -ne 0 ]; then
  log "[ERROR] Questo script deve essere eseguito come root"
  exit 1
fi

RAW_DOMAINS="$1"
if [ -z "$RAW_DOMAINS" ]; then
  log "[ERROR] Parametro mancante: domain"
  exit 1
fi

if [ -f "/var/www/conf/httpd_config.xml" ]; then
  LSWS_CONF="/var/www/conf/httpd_config.xml"
elif [ -f "/usr/local/lsws/conf/httpd_config.xml" ]; then
  LSWS_CONF="/usr/local/lsws/conf/httpd_config.xml"
else
  log "[ERROR] Config LiteSpeed XML non trovata"
  exit 1
fi

DOMAINS=$(echo "$RAW_DOMAINS" | tr ',;' '  ' | xargs)
if [ -z "$DOMAINS" ]; then
  log "[ERROR] Nessun dominio valido"
  exit 1
fi

remove_from_config() {
  local domain="$1"
  LSWS_CONF_PATH="$LSWS_CONF" DOMAIN_NAME="$domain" python3 - <<'PY'
import os
import re
from pathlib import Path

conf_path = Path(os.environ["LSWS_CONF_PATH"])
domain = os.environ["DOMAIN_NAME"]
text = conf_path.read_text()

# 1. Rimuove la SNI cert del dominio dai listener HTTPS
text = re.sub(
    r"<cert><keyFile>/etc/letsencrypt/live/" + re.escape(domain) + r"/privkey\.pem</keyFile>.*?</cert>",
    "",
    text,
    flags=re.S,
)

# 2. Rimuove vhostMap dai listener
text = re.sub(
    r"<vhostMap><vhost>" + re.escape(domain) + r"</vhost><domain>" + re.escape(domain) + r"</domain></vhostMap>",
    "",
    text,
)

# 3. Rimuove virtualHost dalla virtualHostList
text = re.sub(
    r"<virtualHost><name>" + re.escape(domain) + r"</name>.*?</virtualHost>",
    "",
    text,
    flags=re.S,
)

# 4. Rimuove certList vuote
text = re.sub(r"<certList>\s*</certList>", "", text, flags=re.S)

conf_path.write_text(text)
print(f"  [INFO] Configurazione LiteSpeed aggiornata per {domain}")
PY
}

for domain in $DOMAINS; do
  [ -z "$domain" ] && continue

  log "[INFO] Rimuovo dominio $domain"

  # Rimuove certificato Let's Encrypt
  if command -v certbot >/dev/null 2>&1; then
    log "  Rimozione certificato Let's Encrypt..."
    certbot delete --cert-name "$domain" --non-interactive || true
  fi

  rm -rf "/etc/letsencrypt/live/$domain" \
         "/etc/letsencrypt/archive/$domain" \
         "/etc/letsencrypt/renewal/$domain.conf" || true

  # Rimuove vHost directory
  log "  Rimozione vHost directory: /var/www/conf/vhosts/$domain"
  rm -rf "/var/www/conf/vhosts/$domain"

  # Rimuove configurazioni da httpd_config.xml
  log "  Aggiornamento configurazione LiteSpeed..."
  remove_from_config "$domain"

  log "[OK] Dominio $domain rimosso completamente"
done

log "[INFO] Reload LiteSpeed..."
sudo su -c "systemctl reload lsws" 2>/dev/null || systemctl reload lsws 2>/dev/null || true

log "[OK] === RIMOZIONE COMPLETATA ==="
