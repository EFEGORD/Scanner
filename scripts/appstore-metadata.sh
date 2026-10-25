#!/usr/bin/env bash
# Llena la ficha de UltraScanner en App Store Connect desde AppStore/metadata.json. Desde la raíz,
# en Git Bash (adaptado del de UltraVocal):
#
#   scripts/appstore-metadata.sh               aplica los cambios
#   scripts/appstore-metadata.sh --dry-run     solo muestra qué haría
#   scripts/appstore-metadata.sh --solo-texto  textos y datos, sin volver a subir capturas
#
# Corre en la Mac mini con la llave de API que vive allá (no pide sudo). SOLO UltraScanner.
set -euo pipefail

cd "$(dirname "$0")/.."
SOLO_TEXTO=""
if [ "${1:-}" = "--solo-texto" ]; then SOLO_TEXTO=1; shift; fi
MAC_USER="${MAC_USER:-fernandojimenezgordillo}"
MAC_HOST="${MAC_HOST:-mac-mini-de-fernando.local}"
REMOTE_DIR='$HOME/Library/Developer/UltraScannerASC'

ssh "$MAC_USER@$MAC_HOST" "mkdir -p $REMOTE_DIR"
ssh "$MAC_USER@$MAC_HOST" "cat > $REMOTE_DIR/asc_metadata.py" < scripts/asc_metadata.py
# El contacto del revisor (nombre, teléfono y correo) vive en AppStore/contacto.local.json, fuera de git.
python -I - AppStore/metadata.json AppStore/contacto.local.json "$SOLO_TEXTO" <<'EOF' | ssh "$MAC_USER@$MAC_HOST" "cat > $REMOTE_DIR/metadata.json"
import json, os, sys
meta = json.load(open(sys.argv[1], encoding="utf-8"))
if os.path.exists(sys.argv[2]):
    meta["reviewContact"] = json.load(open(sys.argv[2], encoding="utf-8"))
if sys.argv[3]:
    meta.pop("screenshots", None)
    meta.pop("previews", None)
sys.stdout.buffer.write(json.dumps(meta, ensure_ascii=False).encode("utf-8"))
EOF
# Capturas (AppStore/capturas/<locale>/*.png), si ya existen.
ssh "$MAC_USER@$MAC_HOST" "rm -rf $REMOTE_DIR/capturas && mkdir -p $REMOTE_DIR/capturas"
if [ -d AppStore/capturas ]; then
  tar -C AppStore/capturas -cf - . | ssh "$MAC_USER@$MAC_HOST" "tar -xf - -C $REMOTE_DIR/capturas"
fi
ssh "$MAC_USER@$MAC_HOST" "cd $REMOTE_DIR && python3 asc_metadata.py metadata.json $*"
