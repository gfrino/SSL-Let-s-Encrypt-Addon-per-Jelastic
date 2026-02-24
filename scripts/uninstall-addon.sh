#!/bin/bash
set -e

LOG_FILE="/var/log/wp-multisite-ssl-manager.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "[INFO] Avvio uninstall-addon"
echo "[INFO] User: $(id -u) ($(id -un))"

if [ "$(id -u)" -ne 0 ]; then
  echo "[ERROR] Questo script deve essere eseguito come root"
  exit 1
fi

VHOSTS_DIR="/var/www/conf/vhosts"
LE_DIR="/etc/letsencrypt/live"

DOMAINS=""
if [ -d "$VHOSTS_DIR" ]; then
  DOMAINS=$(ls -1d "$VHOSTS_DIR"/*/ 2>/dev/null | xargs -n1 basename | sort || true)
fi

if [ -n "$DOMAINS" ]; then
  for domain in $DOMAINS; do
    echo "[INFO] Rimuovo dominio $domain"
    if command -v certbot >/dev/null 2>&1; then
      certbot delete --cert-name "$domain" --non-interactive || true
    fi

    rm -rf "/etc/letsencrypt/live/$domain" \
           "/etc/letsencrypt/archive/$domain" \
           "/etc/letsencrypt/renewal/$domain.conf" || true

    rm -rf "$VHOSTS_DIR/$domain" || true
  done
else
  echo "[INFO] Nessun vHost trovato da rimuovere"
fi

# Rimuove la riga di cron per certbot renew
crontab -l 2>/dev/null | grep -v "certbot renew --quiet" | crontab - || true

# Pulisce la cartella vhosts se vuota
rmdir "$VHOSTS_DIR" 2>/dev/null || true

# Pulisce log addon
rm -f "$LOG_FILE" || true

echo "[OK] Addon disinstallato (configurazioni pulite)"
