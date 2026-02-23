#!/bin/bash
set -e

echo "[INFO] Installazione base SSL manager"

# Certbot
if ! command -v certbot >/dev/null 2>&1; then
  if command -v dnf >/dev/null 2>&1; then
    echo "[INFO] Uso dnf per installare certbot"
    dnf -y install epel-release
    dnf -y install certbot
  else
    echo "[INFO] Uso yum per installare certbot"
    yum -y install epel-release
    yum -y install certbot
  fi
fi

# Cron renewal
if ! crontab -l | grep -q "certbot renew"; then
  (crontab -l 2>/dev/null; echo "0 3 * * * certbot renew --quiet && systemctl reload lsws") | crontab -
fi

mkdir -p /var/www/conf/vhosts
