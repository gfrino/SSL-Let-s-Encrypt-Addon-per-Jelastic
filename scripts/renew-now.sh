#!/bin/bash
set -e

echo "[INFO] Rinnovo certificati Let’s Encrypt"
certbot renew --quiet
systemctl reload lsws

echo "[OK] Rinnovo completato e LiteSpeed ricaricato"
