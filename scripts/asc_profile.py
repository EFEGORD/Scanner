#!/usr/bin/env python3
"""Crea (o descarga, si ya existe) un perfil de UltraScanner y lo instala en la Mac mini (corre EN
LA MAC MINI):

    scp scripts/asc_bundle_id.py scripts/asc_profile.py mac:Library/Developer/UltraScannerASC/
    ssh mac 'python3 ~/Library/Developer/UltraScannerASC/asc_profile.py <bundle> "<nombre>" <tipo> [--renovar]'

Son cuatro (la app y la extensión de Compartir, cada una para instalar en el iPhone y para la tienda):

    mx.com.claudita.ultrascanner        "UltraScanner Dev"                 desarrollo
    mx.com.claudita.ultrascanner.share  "UltraScanner Compartir Dev"       desarrollo
    mx.com.claudita.ultrascanner        "UltraScanner App Store"           tienda
    mx.com.claudita.ultrascanner.share  "UltraScanner Compartir App Store" tienda

La llave de API no puede firmar en la nube (Xcode no le crea perfiles), así que la firma es manual con
estos perfiles (project.yml). Vuelve a correrlo con --renovar cuando venzan, cambie un certificado, se
agregue un iPhone (los de desarrollo llevan los iPhone registrados) o cambien las capacidades.

Usa los certificados «Apple Development» y «Apple Distribution» que ya están en el llavero de la Mac
(el de distribución es el mismo de UltraVocal, ~/.appstoreconnect/distribucion) y la llave de API de
~/.appstoreconnect/asc.env.
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

KINDS = {
    "tienda": ("IOS_APP_STORE", "Apple Distribution"),
    "desarrollo": ("IOS_APP_DEVELOPMENT", "Apple Development"),
}


def keychain_sha1s(kind):
    out = subprocess.run(["security", "find-identity", "-v", "-p", "codesigning"],
                         capture_output=True, text=True, check=True).stdout
    found = {line.split()[1].upper() for line in out.splitlines() if f'"{kind}' in line}
    if not found:
        raise SystemExit(f"No hay certificado «{kind}» en el llavero de la Mac.")
    return found


def main():
    identifier, name, kind = sys.argv[1], sys.argv[2], sys.argv[3]
    renew = "--renovar" in sys.argv[4:]
    profile_type, certificate_kind = KINDS[kind]
    jwt = token(load_env())

    query = urllib.parse.urlencode({"filter[identifier]": identifier, "limit": 200})
    bundle = next((b for b in call(jwt, "GET", f"/v1/bundleIds?{query}")["data"]
                   if b["attributes"]["identifier"] == identifier), None)
    if not bundle:
        raise SystemExit(f"El bundle {identifier} no está registrado (scripts/asc_app_group.py).")

    # Los certificados de la API que corresponden a los del llavero (misma huella SHA-1).
    wanted = keychain_sha1s(certificate_kind)
    certificates = [c for c in call(jwt, "GET", "/v1/certificates?limit=200")["data"]
                    if c["attributes"].get("certificateContent")
                    and hashlib.sha1(base64.b64decode(c["attributes"]["certificateContent"])).hexdigest().upper() in wanted]
    if not certificates:
        raise SystemExit(f"Ningún certificado «{certificate_kind}» del llavero aparece en la cuenta.")

    # Al cambiar las capacidades del bundle, Apple invalida sus perfiles: esos se borran y se
    # vuelven a crear con el mismo nombre (y todos, con --renovar).
    query = urllib.parse.urlencode({"filter[name]": name, "limit": 200})
    profile = None
    for p in call(jwt, "GET", f"/v1/profiles?{query}")["data"]:
        if p["attributes"]["name"] != name:
            continue
        if p["attributes"]["profileState"] == "ACTIVE" and not renew:
            profile = p
        else:
            call(jwt, "DELETE", f"/v1/profiles/{p['id']}")
            print(f"Borrado: {name} ({p['attributes']['profileState']})")
    if profile:
        print(f"Ya existe: {name}")
    else:
        relationships = {
            "bundleId": {"data": {"type": "bundleIds", "id": bundle["id"]}},
            "certificates": {"data": [{"type": "certificates", "id": c["id"]} for c in certificates]},
        }
        if kind == "desarrollo":
            devices = call(jwt, "GET", "/v1/devices?filter[platform]=IOS&filter[status]=ENABLED&limit=200")["data"]
            relationships["devices"] = {"data": [{"type": "devices", "id": d["id"]} for d in devices]}
        profile = call(jwt, "POST", "/v1/profiles", {"data": {
            "type": "profiles",
            "attributes": {"name": name, "profileType": profile_type},
            "relationships": relationships,
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
    groups = info["Entitlements"].get("com.apple.security.application-groups", [])
    print(f"Instalado: {info['Name']} ({info['UUID']}), vence {info['ExpirationDate']:%Y-%m-%d}, "
          f"App Groups: {', '.join(groups) or 'ninguno'}")


if __name__ == "__main__":
    main()
