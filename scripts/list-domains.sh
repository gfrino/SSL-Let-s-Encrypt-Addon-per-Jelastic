#!/bin/bash
set -e

LOG_FILE="/var/log/wp-multisite-ssl-manager.log"
exec > >(tee -a "$LOG_FILE") 2>&1

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "[INFO] === LISTA DOMINI CONFIGURATI ==="

VHOSTS_DIR="/var/www/conf/vhosts"
LE_DIR="/etc/letsencrypt/live"

log "[INFO] Domini con vHost configurato:"
if [ -d "$VHOSTS_DIR" ]; then
  VHOSTS=$(ls -1d "$VHOSTS_DIR"/*/ 2>/dev/null | xargs -n1 basename | sort || true)
  if [ -n "$VHOSTS" ]; then
    echo "$VHOSTS" | while read domain; do
      log "  ✓ $domain"
    done
  else
    log "  (nessun vHost trovato)"
  fi
else
  log "  (nessun vHost trovato)"
fi

echo ""
log "[INFO] Certificati Let's Encrypt (live):"
if [ -d "$LE_DIR" ]; then
  CERTS=$(ls -1d "$LE_DIR"/*/ 2>/dev/null | xargs -n1 basename | sort || true)
  if [ -n "$CERTS" ]; then
    echo "$CERTS" | while read domain; do
      CERT_FILE="$LE_DIR/$domain/cert.pem"
      if [ -f "$CERT_FILE" ]; then
        EXPIRY=$(openssl x509 -in "$CERT_FILE" -noout -enddate 2>/dev/null | cut -d= -f2)
        log "  ✓ $domain (scadenza: $EXPIRY)"
      else
        log "  ✓ $domain (file certificato non trovato)"
      fi
    done
  else
    log "  (nessun certificato trovato)"
  fi
else
  log "  (nessun certificato trovato)"
fi

log "[INFO] === FINE LISTA ==="
