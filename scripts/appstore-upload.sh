#!/usr/bin/env bash
# Sube UltraScanner a App Store Connect (TestFlight) desde Windows (Git Bash), compilando en la Mac
# mini. Antes corre las pruebas. Desde la raíz del proyecto:
#
#   scripts/appstore-upload.sh
#
# Requisitos: el perfil «UltraScanner App Store» (scripts/asc_profile.py) y el certificado
# «Apple Distribution» en el llavero de la Mac. La firma solo funciona en la sesión gráfica: si el
# agente de UltraVocal está corriendo allí (UltraVocalApp: scripts/deploy-ios.sh agente), sube sin
# contraseña; si no, pide la contraseña de sudo de la Mac.
set -euo pipefail

cd "$(dirname "$0")/.."
MAC_USER="${MAC_USER:-fernandojimenezgordillo}"
MAC_HOST="${MAC_HOST:-mac-mini-de-fernando.local}"
MAC_PATH="${MAC_PATH:-/Users/fernandojimenezgordillo/Documents/UltraScanner}"
AGENT_DIR="/Users/$MAC_USER/Library/Caches/ultravocal-agent"
# Número de compilación creciente: fecha y hora (App Store Connect exige uno nuevo cada subida).
BUILD_NUMBER="$(date +%Y%m%d%H%M)"

echo "==> Pruebas (también copia el proyecto a la Mac)"
TEST_LOG="$(mktemp)"
scripts/deploy-ios.sh test 2>&1 | tee "$TEST_LOG" | grep -E "Executed [0-9]+ tests, .* in .*\) seconds$|TEST (SUCCEEDED|FAILED)|: error:" | tail -3 || true
if ! grep -q "TEST SUCCEEDED" "$TEST_LOG" || grep -q "TEST FAILED\|BUILD FAILED" "$TEST_LOG"; then
  rm -f "$TEST_LOG"
  echo "Las pruebas no pasaron: no se sube nada." >&2
  exit 1
fi
rm -f "$TEST_LOG"

REMOTE=$(cat <<EOS
set -euo pipefail
cd $(printf '%q' "$MAC_PATH")
if ! launchctl print gui/\$(id -u) >/dev/null 2>&1; then
  echo "ERROR: no hay sesión gráfica para tu usuario en la Mac. Inicia sesión y reintenta." >&2
  exit 1
fi
xcodegen generate --quiet
chmod +x scripts/mac-build.sh scripts/mac-appstore.sh
AGENT=$(printf '%q' "$AGENT_DIR")
if [ \$(( \$(date +%s) - \$(cat \$AGENT/heartbeat 2>/dev/null || echo 0) )) -lt 10 ]; then
  # Agente vivo: el número de compilación va en el lugar del UDID (mac-build.sh appstore).
  id=\$(date +%s)-\$\$
  printf '%s\n' $(printf '%q' "$MAC_PATH") appstore $BUILD_NUMBER UltraScanner > \$AGENT/jobs/\$id.tmp
  mv \$AGENT/jobs/\$id.tmp \$AGENT/jobs/\$id.job
  touch \$AGENT/\$id.log
  tail -f \$AGENT/\$id.log &
  tailer=\$!
  while [ ! -f \$AGENT/\$id.status ]; do sleep 1; done
  sleep 1
  kill \$tailer 2>/dev/null || true
  code=\$(cat \$AGENT/\$id.status)
  rm -f \$AGENT/\$id.status \$AGENT/\$id.log
  exit \$code
fi
echo "    (sin agente: pide la contraseña de sudo de la Mac)"
sudo launchctl asuser \$(id -u) sudo -u \$(whoami) \
  zsh -lc "cd $(printf '%q' "$MAC_PATH") && ./scripts/mac-appstore.sh $BUILD_NUMBER"
EOS
)

echo "==> Archivando y subiendo UltraScanner ($BUILD_NUMBER) desde $MAC_HOST"
ssh -t "$MAC_USER@$MAC_HOST" "zsh -lc $(printf '%q' "$REMOTE")"
