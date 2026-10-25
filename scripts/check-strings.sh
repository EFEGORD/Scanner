#!/usr/bin/env bash
# Revisa que cada texto de la app tenga traducción en UltraScanner/Localizable.xcstrings.
# Las llaves las saca el compilador (SWIFT_EMIT_LOC_STRINGS) al compilar, así que primero:
#
#   scripts/deploy-ios.sh sim
#   scripts/check-strings.sh
#
# Lista los textos que faltan en el catálogo (agrégalos con su inglés) y los que ya no se usan.
set -euo pipefail

MAC_USER="${MAC_USER:-fernandojimenezgordillo}"
MAC_HOST="${MAC_HOST:-mac-mini-de-fernando.local}"
MAC_PATH="${MAC_PATH:-/Users/fernandojimenezgordillo/Documents/UltraScanner}"

ssh "$MAC_USER@$MAC_HOST" "python3 - $(printf '%q' "$MAC_PATH")" <<'EOF'
import glob, json, os, sys

build = os.path.expanduser("~/Library/Developer/UltraScannerBuild/Build/Intermediates.noindex/"
                           "UltraScanner.build/Debug-iphonesimulator/UltraScanner.build")
used = set()
for path in glob.glob(f"{build}/Objects-normal/*/*.stringsdata"):
    for entries in json.load(open(path)).get("tables", {}).values():
        used.update(entry["key"] for entry in entries)
if not used:
    sys.exit("No hay llaves: corre primero scripts/deploy-ios.sh sim")

catalog = json.load(open(f"{sys.argv[1]}/UltraScanner/Localizable.xcstrings"))["strings"]
missing = sorted(key for key in used
                 if key not in catalog
                 or (catalog[key].get("shouldTranslate", True)
                     and "en" not in catalog[key].get("localizations", {})))
unused = sorted(set(catalog) - used)

for key in missing:
    print(f"Sin traducir: {key}")
for key in unused:
    print(f"Sin usar:     {key}")
print(f"{len(used)} textos, {len(missing)} sin traducir, {len(unused)} sin usar")
sys.exit(1 if missing else 0)
EOF
