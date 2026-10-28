#!/usr/bin/env bash
# Corre EN LA MAC MINI, dentro de la sesión gráfica (lo lanza appstore-upload.sh a través de
# mac-build.sh appstore). Archiva UltraScanner en Release, revisa que vaya lista para la tienda y la
# sube a App Store Connect con la llave de API.
#
#   mac-appstore.sh <número de compilación>
set -euo pipefail

BUILD_NUMBER="$1"
SCHEME="UltraScanner"
BUNDLE_ID="mx.com.claudita.ultrascanner"
TEAM_ID="C6XD8H2J47" # Fernando Jimenez Gordillo (Apple Developer Program)
PROFILE="UltraScanner App Store" # creados con scripts/asc_profile.py
SHARE_PROFILE="UltraScanner Compartir App Store"
OUT="$HOME/Library/Developer/UltraScannerAppStore"

ASC_ENV="$HOME/.appstoreconnect/asc.env"
[ -f "$ASC_ENV" ] || { echo "Falta $ASC_ENV con la llave de App Store Connect." >&2; exit 1; }
# shellcheck source=/dev/null
. "$ASC_ENV"

cd "$(dirname "$0")/.."
rm -rf "$OUT"
mkdir -p "$OUT"
AUTH=(-authenticationKeyPath "$ASC_KEY_PATH" -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID")

echo "--> Archivando $SCHEME ($BUILD_NUMBER)"
xcodebuild archive \
  -project UltraScanner.xcodeproj \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -archivePath "$OUT/UltraScanner.xcarchive" \
  -derivedDataPath "$OUT/build" \
  -allowProvisioningUpdates "${AUTH[@]}" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  | grep -E "error:|ARCHIVE (SUCCEEDED|FAILED)" || true

APP="$OUT/UltraScanner.xcarchive/Products/Applications/UltraScanner.app"
[ -d "$APP" ] || { echo "No se generó el archivo: revisa los errores de arriba." >&2; exit 1; }

echo "--> Revisando que vaya lista para la tienda"
plist() { /usr/libexec/PlistBuddy -c "Print :$1" "$APP/Info.plist" 2>/dev/null || true; }
[ "$(plist CFBundleIdentifier)" = "$BUNDLE_ID" ] || { echo "ALTO: el bundle es $(plist CFBundleIdentifier), no $BUNDLE_ID." >&2; exit 1; }
# Anuncios: los IDs de prueba de Google (ca-app-pub-3940256099942544) no pueden ir a la tienda.
if plist GADApplicationIdentifier | grep -q 3940256099942544 || plist USInterstitialAdUnitID | grep -q 3940256099942544; then
  echo "ALTO: lleva los IDs de AdMob de prueba; pon los de la cuenta en project.yml (Release)." >&2
  exit 1
fi
# El modo demo de las capturas (Demo/DemoMode.swift) solo existe en Debug.
if strings "$APP/UltraScanner" | grep -q "USScreen"; then
  echo "ALTO: el binario trae el modo demo de las capturas." >&2
  exit 1
fi
[ -f "$APP/PrivacyInfo.xcprivacy" ] || { echo "ALTO: falta PrivacyInfo.xcprivacy." >&2; exit 1; }
[ -d "$APP/en.lproj" ] || { echo "ALTO: falta la traducción al inglés (en.lproj)." >&2; exit 1; }
# Sin este archivo Firebase Analytics no arranca (no está en git: ver SETUP.md).
FIREBASE_ID=$(/usr/libexec/PlistBuddy -c "Print :BUNDLE_ID" "$APP/GoogleService-Info.plist" 2>/dev/null || true)
[ "$FIREBASE_ID" = "$BUNDLE_ID" ] || { echo "ALTO: falta UltraScanner/GoogleService-Info.plist de Firebase (o es de otra app: $FIREBASE_ID)." >&2; exit 1; }
echo "    OK: $BUNDLE_ID $(plist CFBundleShortVersionString) ($(plist CFBundleVersion)), AdMob de la cuenta, Firebase, sin modo demo, con inglés."

cat > "$OUT/ExportOptions.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>upload</string>
  <key>teamID</key><string>$TEAM_ID</string>
  <!-- Firma manual: la llave de API no tiene permiso de firma en la nube. El certificado
       «Apple Distribution» vive en el llavero de la Mac (el mismo de UltraVocal). -->
  <key>signingStyle</key><string>manual</string>
  <key>signingCertificate</key><string>Apple Distribution</string>
  <key>provisioningProfiles</key>
  <dict>
    <key>$BUNDLE_ID</key><string>$PROFILE</string>
    <key>$BUNDLE_ID.share</key><string>$SHARE_PROFILE</string>
  </dict>
  <key>uploadSymbols</key><true/>
  <key>manageAppVersionAndBuildNumber</key><false/>
</dict>
</plist>
EOF

echo "--> Subiendo a App Store Connect"
# Xcode arma el .ipa con /usr/bin/rsync, que lanza «rsync» del PATH como servidor; el de Homebrew
# (3.x) no entiende sus opciones y falla con «Copy failed». Para exportar, primero las del sistema.
PATH="/usr/bin:/bin:/usr/sbin:/sbin:$PATH" xcodebuild -exportArchive \
  -archivePath "$OUT/UltraScanner.xcarchive" \
  -exportOptionsPlist "$OUT/ExportOptions.plist" \
  -exportPath "$OUT/export" \
  -allowProvisioningUpdates "${AUTH[@]}" \
  > "$OUT/export.log" 2>&1 || true
grep -E "error:|Upload|EXPORT (SUCCEEDED|FAILED)|uploaded" "$OUT/export.log" || true

if ! grep -q "EXPORT SUCCEEDED" "$OUT/export.log"; then
  echo "NO se subió: falló la firma o la subida (detalle en $OUT/export.log)." >&2
  exit 1
fi
echo "Listo: la compilación $BUILD_NUMBER aparece en App Store Connect › TestFlight en unos minutos."
