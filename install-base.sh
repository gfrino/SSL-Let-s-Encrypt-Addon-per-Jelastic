#!/bin/bash
set -e

echo "[INFO] Installazione base SSL manager"

# Certbot
if ! command -v certbot >/dev/null 2>&1; then
  yum install -y epel-release
  yum install -y certbot
fi

# Cron renewal
if ! crontab -l | grep -q "certbot renew"; then
  (crontab -l 2>/dev/null; echo "0 3 * * * certbot renew --quiet && systemctl reload lsws") | crontab -
fi

mkdir -p /var/www/conf/vhosts
