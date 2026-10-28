#!/usr/bin/env bash
# Capturas de App Store de UltraScanner (6.9", 1320 × 2868) en español e inglés, con documentos
# ficticios del modo demo (solo existe en Debug, ver Demo/DemoMode.swift). Desde la raíz, en Git Bash:
#
#   scripts/screenshots.sh
#
# Deja los PNG en AppStore/capturas/<es-MX|en-US>/. Para subirlos: scripts/appstore-metadata.sh
set -euo pipefail

cd "$(dirname "$0")/.."
MAC_USER="${MAC_USER:-fernandojimenezgordillo}"
MAC_HOST="${MAC_HOST:-mac-mini-de-fernando.local}"
# Carpeta propia: no toca la copia de scripts/deploy-ios.sh ni su compilación.
SRC="/Users/$MAC_USER/Library/Developer/UltraScannerShotsSrc"
SIMULATOR="${SIMULATOR:-iPhone 17 Pro Max}"
SCREENS="library viewer search combine security" # el documento firmado, segundo
# Para pruebas de diseño: LANGS="es-MX:es:es_MX" DEST=build/pantallas scripts/screenshots.sh
LANGS="${LANGS:-es-MX:es:es_MX en-US:en:en_US}"
DEST="${DEST:-AppStore/capturas}"

echo "==> Copiando el proyecto"
ssh "$MAC_USER@$MAC_HOST" "rm -rf $SRC && mkdir -p $SRC"
tar --exclude='./build' --exclude='./*.xcodeproj' --exclude='./.claude' --exclude='./.git' \
    --exclude='./AppStore/capturas' --exclude='./web' -cf - . \
  | ssh "$MAC_USER@$MAC_HOST" "tar -xf - -C $SRC"

REMOTE=$(cat <<EOS
set -euo pipefail
cd $SRC
SIM=$(printf '%q' "$SIMULATOR")
BUNDLE=mx.com.claudita.ultrascanner
BUILD=\$HOME/Library/Developer/UltraScannerShotsBuild
OUT=\$HOME/Library/Developer/UltraScannerShots
xcodegen generate --quiet
# Firma local («-», sin cuenta): sin firma el Keychain del simulador falla (-34018), cada
# arranque crea otra llave y no se pueden leer las páginas que guardó el anterior.
echo "--> Compilando (Debug, simulador)"
xcodebuild build -project UltraScanner.xcodeproj -scheme UltraScanner -destination "platform=iOS Simulator,name=\$SIM" \
  -derivedDataPath "\$BUILD" CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- PROVISIONING_PROFILE_SPECIFIER= 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)" || true
APP="\$BUILD/Build/Products/Debug-iphonesimulator/UltraScanner.app"
[ -d "\$APP" ] || { echo "No se compiló la app." >&2; exit 1; }

xcrun simctl boot "\$SIM" 2>/dev/null || true
xcrun simctl bootstatus "\$SIM" -b >/dev/null
xcrun simctl ui "\$SIM" appearance light
xcrun simctl status_bar "\$SIM" override --time "9:41" --dataNetwork wifi --wifiMode active --wifiBars 3 \
  --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100

rm -rf "\$OUT"
for pair in $LANGS; do
  IFS=: read -r folder lang locale <<< "\$pair"
  mkdir -p "\$OUT/\$folder"
  # Instalación limpia por idioma: el modo demo llena la biblioteca en el idioma del teléfono.
  xcrun simctl uninstall "\$SIM" \$BUNDLE 2>/dev/null || true
  xcrun simctl install "\$SIM" "\$APP"
  xcrun simctl launch "\$SIM" \$BUNDLE -USDemo YES -USScreen library \
    -AppleLanguages "(\$lang)" -AppleLocale \$locale >/dev/null
  sleep 25 # lee el texto de los documentos de ejemplo y los cifra
  n=1
  for screen in $SCREENS; do
    xcrun simctl terminate "\$SIM" \$BUNDLE 2>/dev/null || true
    xcrun simctl launch "\$SIM" \$BUNDLE -USDemo YES -USScreen \$screen \
      -AppleLanguages "(\$lang)" -AppleLocale \$locale >/dev/null
    sleep 6
    xcrun simctl io "\$SIM" screenshot "\$OUT/\$folder/\$n-\$screen.png" >/dev/null 2>&1
    echo "    \$folder/\$n-\$screen.png"
    n=\$((n + 1))
  done
done
xcrun simctl terminate "\$SIM" \$BUNDLE 2>/dev/null || true
xcrun simctl status_bar "\$SIM" clear
EOS
)

echo "==> Capturas en el simulador ($SIMULATOR)"
ssh "$MAC_USER@$MAC_HOST" "zsh -lc $(printf '%q' "$REMOTE")"

echo "==> Trayendo las capturas"
rm -rf "$DEST" && mkdir -p "$DEST"
ssh "$MAC_USER@$MAC_HOST" 'cd $HOME/Library/Developer/UltraScannerShots && tar -cf - .' | tar -xf - -C "$DEST"
find "$DEST" -name '*.png' | sort
