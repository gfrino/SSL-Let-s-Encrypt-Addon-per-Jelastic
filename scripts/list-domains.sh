#!/bin/bash
set -e

VHOSTS_DIR="/var/www/conf/vhosts"
LE_DIR="/etc/letsencrypt/live"

echo "[INFO] Domini configurati (vHost):"
if [ -d "$VHOSTS_DIR" ]; then
  VHOSTS=$(ls -1d "$VHOSTS_DIR"/*/ 2>/dev/null | xargs -n1 basename | sort || true)
  if [ -n "$VHOSTS" ]; then
    echo "$VHOSTS" | sed 's/^/ - /'
  else
    echo " - (nessun vHost trovato)"
  fi
else
  echo " - (nessun vHost trovato)"
fi

echo ""
echo "[INFO] Certificati Let’s Encrypt (live):"
if [ -d "$LE_DIR" ]; then
  CERTS=$(ls -1d "$LE_DIR"/*/ 2>/dev/null | xargs -n1 basename | sort || true)
  if [ -n "$CERTS" ]; then
    echo "$CERTS" | sed 's/^/ - /'
  else
    echo " - (nessun certificato trovato)"
  fi
else
  echo " - (nessun certificato trovato)"
fi
