#!/bin/bash
set -e

LOG_FILE="/var/log/wp-multisite-ssl-manager.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "[INFO] Stato rinnovo certificati"

# Cron check
if crontab -l 2>/dev/null | grep -q "certbot renew"; then
  echo "[OK] Cron certbot presente"
else
  echo "[WARN] Cron certbot NON presente"
fi

echo ""

echo "[INFO] Scadenze certificati (certbot certificates):"
if command -v certbot >/dev/null 2>&1; then
  certbot certificates || true
else
  echo "[WARN] certbot non installato"
fi
