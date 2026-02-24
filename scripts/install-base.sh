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
  (crontab -l 2>/dev/null; echo "0 3 * * * certbot renew --quiet && sudo su -c 'systemctl restart lshttpd'") | crontab -
fi

# Configura vhost _default_ wildcard se non esiste (necessario per WordPress Multisite su Jelastic)
if [ -f "/var/www/conf/httpd_config.xml" ]; then
  LSWS_CONF="/var/www/conf/httpd_config.xml"
  python3 - <<'PY'
import re
from pathlib import Path

p = Path('/var/www/conf/httpd_config.xml')
text = p.read_text()
changed = False

# 1. Aggiunge vhost _default_ wildcard se non presente
if '<name>_default_</name>' not in text:
    default_vh = (
        '<virtualHost>'
        '<name>_default_</name>'
        '<vhRoot>/var/www/webroot</vhRoot>'
        '<configFile>/var/www/conf/vhconf.xml</configFile>'
        '<allowSymbolLink>1</allowSymbolLink>'
        '<enableScript>1</enableScript>'
        '<restrained>1</restrained>'
        '<setUIDMode>0</setUIDMode>'
        '<chrootMode>0</chrootMode>'
        '</virtualHost>'
    )
    text = re.sub(
        r'(<virtualHostList>)',
        r'\1' + default_vh,
        text, count=1, flags=re.S
    )
    changed = True
    print('[INFO] Vhost _default_ aggiunto')

# 2. Aggiunge wildcard vhostMap ai listener HTTP/HTTPS se mancano
wildcard_map = '<vhostMapList><vhostMap><vhost>_default_</vhost><domain>*</domain></vhostMap></vhostMapList>'
for addr in [r'\*:80', r'\[::\]:80', r'\*:443', r'\[::\]:443']:
    pattern = r'(<address>' + addr + r'</address>\s*<secure>[01]</secure>)(?!\s*<vhostMapList>)'
    new_text = re.sub(pattern, r'\1' + wildcard_map, text, count=1, flags=re.S)
    if new_text != text:
        changed = True
    text = new_text

if changed:
    p.write_text(text)
    print('[INFO] httpd_config.xml aggiornato con vhost wildcard')
else:
    print('[INFO] Configurazione wildcard gia presente')
PY
  sudo su -c "systemctl restart lshttpd" 2>/dev/null || true
fi

# Crea il file di log se non esiste (così appare nel pannello Jelastic)
LOG_FILE="/var/log/wp-multisite-ssl-manager.log"
touch "$LOG_FILE"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] SSL Manager installato" >> "$LOG_FILE"
