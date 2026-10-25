#!/usr/bin/env bash
# Corre EN LA MAC MINI, dentro de la sesión gráfica (lo lanza deploy-ios.sh, directo con sudo o a
# través del agente de UltraVocal). Firma con la llave de API de App Store Connect, así que no
# necesita una cuenta iniciada en Xcode → Settings → Accounts.
#
#   mac-build.sh <Release|Debug> <UDID del iPhone> [Scanner]
set -euo pipefail

CONFIG="$1"
DEVICE="$2"
SCHEME="${3:-Scanner}"
TEAM_ID="C6XD8H2J47" # Fernando Jimenez Gordillo (Apple Developer Program)
BUNDLE_ID="com.efegord.scanner"

# ASC_KEY_ID, ASC_ISSUER_ID y ASC_KEY_PATH. Vive fuera del proyecto, con permisos 600.
ASC_ENV="$HOME/.appstoreconnect/asc.env"
[ -f "$ASC_ENV" ] || { echo "Falta $ASC_ENV con la llave de App Store Connect." >&2; exit 1; }
# shellcheck source=/dev/null
. "$ASC_ENV"

cd "$(dirname "$0")/.."

# Se compila para "cualquier iPhone" y no para el UDID: con -destination id=... xcodebuild exige
# montar la imagen de desarrollo en el iPhone, y eso falla si está bloqueado. devicectl instala
# sin esa imagen.
echo "--> xcodebuild $SCHEME ($CONFIG)"
xcodebuild \
  -project Scanner.xcodeproj \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  -destination "generic/platform=iOS" \
  -derivedDataPath build \
  -allowProvisioningUpdates \
  -allowProvisioningDeviceRegistration \
  -authenticationKeyPath "$ASC_KEY_PATH" \
  -authenticationKeyID "$ASC_KEY_ID" \
  -authenticationKeyIssuerID "$ASC_ISSUER_ID" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  CODE_SIGN_STYLE=Automatic \
  build | grep -E "error:|warning: .*(sign|provision)|BUILD (SUCCEEDED|FAILED)|Signing Identity|Provisioning Profile" || true

APP="build/Build/Products/$CONFIG-iphoneos/$SCHEME.app"
[ -d "$APP" ] || { echo "No se generó $APP: revisa los errores de arriba." >&2; exit 1; }

echo "--> Instalando en el iPhone"
xcrun devicectl device install app --device "$DEVICE" "$APP"
xcrun devicectl device process launch --device "$DEVICE" "$BUNDLE_ID" >/dev/null 2>&1 || true
