#!/usr/bin/env bash
# Publica el sitio de UltraTools (web/ultratools) en el nginx de la Mac mini:
# https://ultratools.claudita.com.mx — portada, /ultrascanner/ (soporte y privacidad para la
# App Store) y app-ads.txt de AdMob. Desde la raíz del proyecto, en Git Bash:
#
#   scripts/site-deploy.sh
#
# Solo cambia ~/Documents/NGINX/sites/ultratools. La configuración de nginx
# (web/nginx/ultratools.claudita.com.mx.conf) y el certificado se instalaron una vez a mano.
set -euo pipefail

MAC_USER="${MAC_USER:-fernandojimenezgordillo}"
MAC_HOST="${MAC_HOST:-mac-mini-de-fernando.local}"
SITE_PATH="${SITE_PATH:-/Users/fernandojimenezgordillo/Documents/NGINX/sites/ultratools}"

cd "$(dirname "$0")/.."

echo "==> Publicando web/ultratools en $MAC_HOST:$SITE_PATH"
ssh "$MAC_USER@$MAC_HOST" "rm -rf $(printf '%q' "$SITE_PATH.nuevo") && mkdir -p $(printf '%q' "$SITE_PATH.nuevo")"
tar -C web/ultratools -cf - . | ssh "$MAC_USER@$MAC_HOST" "tar -xf - -C $(printf '%q' "$SITE_PATH.nuevo")"
# Cambio de golpe: nginx nunca ve la carpeta a medias.
ssh "$MAC_USER@$MAC_HOST" "rm -rf $(printf '%q' "$SITE_PATH.viejo"); \
  { [ -d $(printf '%q' "$SITE_PATH") ] && mv $(printf '%q' "$SITE_PATH") $(printf '%q' "$SITE_PATH.viejo"); } ; \
  mv $(printf '%q' "$SITE_PATH.nuevo") $(printf '%q' "$SITE_PATH") && rm -rf $(printf '%q' "$SITE_PATH.viejo")"

for path in / /ultrascanner/ /ultrascanner/soporte /ultrascanner/privacidad /app-ads.txt; do
  code=$(curl -s -o /dev/null -w '%{http_code}' "https://ultratools.claudita.com.mx$path" || true)
  echo "  $code  $path"
done
