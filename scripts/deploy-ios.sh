#!/usr/bin/env bash
# Compila UltraScanner en la Mac mini y la instala en el iPhone por WiFi (mismo método que
# UltraVocal). Desde la raíz del proyecto, en Git Bash:
#
#   scripts/deploy-ios.sh           Release en el iPhone
#   scripts/deploy-ios.sh debug     Debug en el iPhone
#   scripts/deploy-ios.sh test      Pruebas automáticas en el simulador (no instala, no pide nada)
#   scripts/deploy-ios.sh sim       Solo compila para el simulador (revisa errores, no instala)
#
# La firma solo funciona dentro de la sesión gráfica de la Mac (desde SSH normal falla con
# errSecInternalComponent). Si el agente de UltraVocal está corriendo allí
# (UltraVocalApp: scripts/deploy-ios.sh agente), instala sin contraseña; si no, pide la
# contraseña de sudo de la Mac.
set -euo pipefail

cd "$(dirname "$0")/.."

MAC_USER="${MAC_USER:-fernandojimenezgordillo}"
MAC_HOST="${MAC_HOST:-mac-mini-de-fernando.local}"
MAC_PATH="${MAC_PATH:-/Users/fernandojimenezgordillo/Documents/UltraScanner}"
# iPhone 12 Pro "EFE", emparejado por WiFi.
IOS_DEVICE="${IOS_DEVICE:-00008101-000308A23C52001E}"
SIMULATOR="${SIMULATOR:-iPhone 17}"
AGENT_DIR="/Users/$MAC_USER/Library/Caches/ultravocal-agent"

case "${1:-release}" in
  release) CONFIG="Release" ;;
  debug)   CONFIG="Debug" ;;
  test)    CONFIG="test" ;;
  sim)     CONFIG="sim" ;;
  *) echo "Uso: deploy-ios.sh [release|debug|test|sim]" >&2; exit 1 ;;
esac

echo "==> Copiando el proyecto a $MAC_HOST:$MAC_PATH"
# Se copia el árbol de trabajo (lo que hay en disco, commiteado o no), sin lo generado ni .git.
ssh "$MAC_USER@$MAC_HOST" "rm -rf $(printf '%q' "$MAC_PATH") && mkdir -p $(printf '%q' "$MAC_PATH")"
tar --exclude='./build' --exclude='./*.xcodeproj' --exclude='./.claude' --exclude='./.git' \
    --exclude='./Design' -cf - . \
  | ssh "$MAC_USER@$MAC_HOST" "tar -xf - -C $(printf '%q' "$MAC_PATH")"

if [ "$CONFIG" = "test" ] || [ "$CONFIG" = "sim" ]; then
  if [ "$CONFIG" = "test" ]; then
    # DerivedData fuera de ~/Documents: macOS protege esa carpeta y, por SSH, XCTest puede
    # quedarse colgado. Se reinicia el simulador para evitar "Busy (Application failed preflight)".
    ACTION=$(cat <<EOS
xcrun simctl shutdown $(printf '%q' "$SIMULATOR") 2>/dev/null || true
xcrun simctl bootstatus $(printf '%q' "$SIMULATOR") -b >/dev/null
xcodebuild test -project UltraScanner.xcodeproj -scheme UltraScanner \
  -destination $(printf '%q' "platform=iOS Simulator,name=$SIMULATOR") \
  -derivedDataPath \$HOME/Library/Developer/UltraScannerBuild CODE_SIGNING_ALLOWED=NO > \$LOG 2>&1 || true
grep -E "error:|Test Case .*(passed|failed)|XCTAssert|Executed|TEST (SUCCEEDED|FAILED)|BUILD (SUCCEEDED|FAILED)" \$LOG || true
grep -q "TEST SUCCEEDED" \$LOG
EOS
)
  else
    ACTION=$(cat <<EOS
xcodebuild build -project UltraScanner.xcodeproj -scheme UltraScanner \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath \$HOME/Library/Developer/UltraScannerBuild CODE_SIGNING_ALLOWED=NO > \$LOG 2>&1 || true
grep -E "error:|BUILD (SUCCEEDED|FAILED)" \$LOG || true
grep -q "BUILD SUCCEEDED" \$LOG
EOS
)
  fi
  REMOTE=$(cat <<EOS
set -euo pipefail
cd $(printf '%q' "$MAC_PATH")
LOG=\$TMPDIR/ultrascanner-$CONFIG.log
xcodegen generate --quiet
$ACTION
EOS
)
  echo "==> $( [ "$CONFIG" = test ] && echo "Corriendo pruebas" || echo "Compilando para el simulador" ) en $MAC_HOST"
  ssh "$MAC_USER@$MAC_HOST" "zsh -lc $(printf '%q' "$REMOTE")"
  exit 0
fi

REMOTE=$(cat <<EOS
set -euo pipefail
cd $(printf '%q' "$MAC_PATH")

if ! launchctl print gui/\$(id -u) >/dev/null 2>&1; then
  echo "ERROR: no hay sesión gráfica para tu usuario en la Mac. Inicia sesión y reintenta." >&2
  exit 1
fi

echo "--> Generando el proyecto (XcodeGen)"
xcodegen generate --quiet

echo "--> Compilando en modo $CONFIG dentro de la sesión gráfica"
chmod +x scripts/mac-build.sh
AGENT=$(printf '%q' "$AGENT_DIR")
if [ \$(( \$(date +%s) - \$(cat \$AGENT/heartbeat 2>/dev/null || echo 0) )) -lt 10 ]; then
  # Agente vivo: se le deja el pedido y se espera su resultado (sin contraseña).
  id=\$(date +%s)-\$\$
  printf '%s\n' $(printf '%q' "$MAC_PATH") $CONFIG $(printf '%q' "$IOS_DEVICE") UltraScanner > \$AGENT/jobs/\$id.tmp
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
  zsh -lc "cd $(printf '%q' "$MAC_PATH") && ./scripts/mac-build.sh $CONFIG $(printf '%q' "$IOS_DEVICE") UltraScanner"
EOS
)

echo "==> Compilando UltraScanner en $MAC_HOST"
ssh -t "$MAC_USER@$MAC_HOST" "zsh -lc $(printf '%q' "$REMOTE")"

echo
echo "Instalada. Abre UltraScanner en el iPhone."
