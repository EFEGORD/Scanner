#!/usr/bin/env python3
"""Crea (o descarga, si ya existe) el perfil de distribución App Store de UltraScanner y lo instala
en la Mac mini (corre EN LA MAC MINI):

    scp scripts/asc_bundle_id.py scripts/asc_profile.py mac:Library/Developer/UltraScannerASC/
    ssh mac 'python3 ~/Library/Developer/UltraScannerASC/asc_profile.py \
        mx.com.claudita.ultrascanner "UltraScanner App Store"'

Ya se corrió una vez (perfil «UltraScanner App Store», vence 2027-10-16). Vuelve a correrlo cuando
venza o si cambia el certificado.

Usa el certificado «Apple Distribution» que ya está en el llavero de la Mac (el mismo de UltraVocal,
~/.appstoreconnect/distribucion) y la llave de API de ~/.appstoreconnect/asc.env.
"""
import base64
import hashlib
import os
import plistlib
import subprocess
import sys
import urllib.parse

# Mismo cliente que asc_bundle_id.py (JWT con openssl, solo biblioteca estándar).
from asc_bundle_id import call, load_env, token

PROFILE_DIRS = ["~/Library/Developer/Xcode/UserData/Provisioning Profiles",
                "~/Library/MobileDevice/Provisioning Profiles"]


def keychain_distribution_sha1():
    out = subprocess.run(["security", "find-identity", "-v", "-p", "codesigning"],
                         capture_output=True, text=True, check=True).stdout
    for line in out.splitlines():
        if "Apple Distribution" in line:
            return line.split()[1].upper()
    raise SystemExit("No hay certificado «Apple Distribution» en el llavero de la Mac.")


def main():
    identifier, name = sys.argv[1], sys.argv[2]
    jwt = token(load_env())

    query = urllib.parse.urlencode({"filter[identifier]": identifier, "limit": 200})
    bundle = next((b for b in call(jwt, "GET", f"/v1/bundleIds?{query}")["data"]
                   if b["attributes"]["identifier"] == identifier), None)
    if not bundle:
        raise SystemExit(f"El bundle {identifier} no está registrado (scripts/asc_bundle_id.py).")

    # El certificado de la API que corresponde al del llavero (misma huella SHA-1).
    wanted = keychain_distribution_sha1()
    certificates = call(jwt, "GET", "/v1/certificates?limit=200")["data"]
    certificate = next((c for c in certificates
                        if c["attributes"].get("certificateContent")
                        and hashlib.sha1(base64.b64decode(c["attributes"]["certificateContent"])).hexdigest().upper() == wanted),
                       None)
    if not certificate:
        raise SystemExit("El certificado de distribución del llavero no aparece en la cuenta.")

    query = urllib.parse.urlencode({"filter[name]": name, "limit": 200})
    profile = next((p for p in call(jwt, "GET", f"/v1/profiles?{query}")["data"]
                    if p["attributes"]["name"] == name and p["attributes"]["profileState"] == "ACTIVE"), None)
    if profile:
        print(f"Ya existe: {name}")
    else:
        profile = call(jwt, "POST", "/v1/profiles", {"data": {
            "type": "profiles",
            "attributes": {"name": name, "profileType": "IOS_APP_STORE"},
            "relationships": {
                "bundleId": {"data": {"type": "bundleIds", "id": bundle["id"]}},
                "certificates": {"data": [{"type": "certificates", "id": certificate["id"]}]},
            },
        }})["data"]
        print(f"Creado: {name}")

    content = base64.b64decode(profile["attributes"]["profileContent"])
    decoded = subprocess.run(["security", "cms", "-D"], input=content, capture_output=True, check=True).stdout
    info = plistlib.loads(decoded)
    for folder in PROFILE_DIRS:
        folder = os.path.expanduser(folder)
        os.makedirs(folder, exist_ok=True)
        with open(os.path.join(folder, f"{info['UUID']}.mobileprovision"), "wb") as f:
            f.write(content)
    print(f"Instalado: {info['Name']} ({info['UUID']}), vence {info['ExpirationDate']:%Y-%m-%d}")


if __name__ == "__main__":
    main()
