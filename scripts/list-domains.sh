#!/bin/bash
set -e

VHOSTS_DIR="/var/www/conf/vhosts"
LE_DIR="/etc/letsencrypt/live"

echo "[INFO] Domini configurati (vHost):"
if [ -d "$VHOSTS_DIR" ]; then
  ls -1 "$VHOSTS_DIR" | sed 's/^/ - /'
else
  echo " - (nessun vHost trovato)"
fi

echo ""
echo "[INFO] Certificati Let’s Encrypt (live):"
if [ -d "$LE_DIR" ]; then
  ls -1 "$LE_DIR" | sed 's/^/ - /'
else
  echo " - (nessun certificato trovato)"
fi
