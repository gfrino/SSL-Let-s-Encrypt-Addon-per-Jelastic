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

DOMAIN="$1"
EMAIL="$2"

DOCROOT="/var/www/webroot/ROOT"
VHOST_DIR="/var/www/conf/vhosts/$DOMAIN"
VHOST_CONF="$VHOST_DIR/vhconf.conf"

echo "[INFO] Aggiungo dominio $DOMAIN"

# Certificato LE
certbot certonly \
  --webroot \
  -w $DOCROOT \
  -d $DOMAIN \
  --email $EMAIL \
  --agree-tos \
  --non-interactive

# VHost
mkdir -p "$VHOST_DIR"

cat > "$VHOST_CONF" <<EOF
$(sed "s|{DOMAIN}|$DOMAIN|g" templates/litespeed-vhost.conf)
EOF

# Reload LiteSpeed
systemctl reload lsws

echo "[OK] Dominio $DOMAIN configurato con SSL"
