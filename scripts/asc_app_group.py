#!/usr/bin/env python3
"""Prepara la extensión de Compartir en la cuenta de Apple Developer (corre EN LA MAC MINI).

    ssh mac 'cd ~/Library/Developer/UltraScannerASC && python3 -' < scripts/asc_app_group.py

Registra el bundle ID de la extensión (mx.com.claudita.ultrascanner.share), activa App Groups en
la app y en la extensión, y dice si el grupo group.mx.com.claudita.ultrascanner ya está asignado a
las dos. El grupo en sí no se puede crear con la API: se crea en developer.apple.com (ver SETUP.md).
Usa asc_bundle_id.py (misma carpeta) para la llave y las llamadas.
"""
import urllib.parse

from asc_bundle_id import call, load_env, token

APP = "mx.com.claudita.ultrascanner"
SHARE = "mx.com.claudita.ultrascanner.share"


def bundle(jwt, identifier, name):
    query = urllib.parse.urlencode({"filter[identifier]": identifier, "limit": 50})
    found = [b for b in call(jwt, "GET", f"/v1/bundleIds?{query}")["data"]
             if b["attributes"]["identifier"] == identifier]
    if found:
        return found[0]
    print(f"Registrando {identifier}")
    return call(jwt, "POST", "/v1/bundleIds", {"data": {"type": "bundleIds", "attributes": {
        "identifier": identifier, "name": name, "platform": "IOS"}}})["data"]


def main():
    jwt = token(load_env())
    for identifier, name in [(APP, "UltraScanner"), (SHARE, "UltraScanner Compartir")]:
        b = bundle(jwt, identifier, name)
        caps = call(jwt, "GET", f"/v1/bundleIds/{b['id']}/bundleIdCapabilities")["data"]
        types = {c["attributes"]["capabilityType"] for c in caps}
        if "APP_GROUPS" not in types:
            call(jwt, "POST", "/v1/bundleIdCapabilities", {"data": {
                "type": "bundleIdCapabilities", "attributes": {"capabilityType": "APP_GROUPS"},
                "relationships": {"bundleId": {"data": {"type": "bundleIds", "id": b["id"]}}}}})
            print(f"{identifier}: App Groups activado")
        else:
            print(f"{identifier}: App Groups ya estaba activado")


if __name__ == "__main__":
    main()
