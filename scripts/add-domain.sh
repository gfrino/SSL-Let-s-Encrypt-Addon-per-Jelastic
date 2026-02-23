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
TEMPLATE_FILE="${TEMPLATE_FILE:-templates/litespeed-vhost.conf}"

LSWS_CONF=""
if [ -f "/var/www/conf/httpd_config.conf" ]; then
  LSWS_CONF="/var/www/conf/httpd_config.conf"
elif [ -f "/usr/local/lsws/conf/httpd_config.conf" ]; then
  LSWS_CONF="/usr/local/lsws/conf/httpd_config.conf"
else
  echo "[ERROR] Config LiteSpeed non trovata (httpd_config.conf)"
  exit 1
fi

if [ ! -f "$TEMPLATE_FILE" ]; then
  echo "[ERROR] Template non trovato: $TEMPLATE_FILE"
  exit 1
fi

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
$(sed "s|{DOMAIN}|$DOMAIN|g" "$TEMPLATE_FILE")
EOF

# Registra il vhost nel file di configurazione principale se mancante
if ! grep -q "^virtualhost[[:space:]]\+$DOMAIN\b" "$LSWS_CONF"; then
  cat >> "$LSWS_CONF" <<EOF

virtualhost $DOMAIN {
  vhRoot                  /var/www
  configFile              /var/www/conf/vhosts/$DOMAIN/vhconf.conf
  allowSymbolLink         1
  enableScript            1
  restrained              1
}
EOF
fi

add_listener_map() {
  local port="$1"
  local tmp
  tmp="$(mktemp)"
  awk -v domain="$DOMAIN" -v port="$port" '
    BEGIN {in_listener=0; addr_match=0; has_map=0}
    /^listener[ \t]+/ {in_listener=1; addr_match=0; has_map=0}
    in_listener && $1=="address" && $2~":"port"$" {addr_match=1}
    in_listener && $1=="map" && $2==domain {has_map=1}
    in_listener && addr_match && /^[ \t]*}/ {
      if (!has_map) print "  map                    " domain " " domain
      print $0
      in_listener=0; addr_match=0; has_map=0
      next
    }
    in_listener && /^[ \t]*}/ {
      in_listener=0; addr_match=0; has_map=0
    }
    {print}
  ' "$LSWS_CONF" > "$tmp" && mv "$tmp" "$LSWS_CONF"
}

add_listener_map 80
add_listener_map 443

# Reload LiteSpeed
systemctl reload lsws

echo "[OK] Dominio $DOMAIN configurato con SSL"
