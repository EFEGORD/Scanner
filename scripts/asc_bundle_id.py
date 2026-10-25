#!/usr/bin/env python3
"""Registra el bundle ID de UltraScanner en la cuenta de Apple Developer (corre EN LA MAC MINI).

    ssh mac 'python3 - mx.com.claudita.ultrascanner UltraScanner' < scripts/asc_bundle_id.py

Si ya existe no hace nada. Usa la llave de API de ~/.appstoreconnect/asc.env (la llave nunca sale
de la Mac); solo biblioteca estándar + openssl, igual que asc_metadata.py de UltraVocal.
"""
import base64
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

API = "https://api.appstoreconnect.apple.com"


def load_env():
    env = {}
    with open(os.path.expanduser("~/.appstoreconnect/asc.env")) as f:
        for line in f:
            line = line.strip()
            if "=" in line and not line.startswith("#"):
                key, value = line.split("=", 1)
                env[key.replace("export ", "").strip()] = os.path.expanduser(value.strip().strip('"').strip("'"))
    return env


def b64(data):
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def der_to_raw(der):
    """Firma ECDSA en DER → r||s de 32 bytes cada uno (lo que pide JWT ES256)."""
    def read_int(buf, i):
        assert buf[i] == 0x02
        length = buf[i + 1]
        value = buf[i + 2:i + 2 + length]
        return value.lstrip(b"\x00").rjust(32, b"\x00"), i + 2 + length
    assert der[0] == 0x30
    i = 2 if der[1] < 0x80 else 3
    r, i = read_int(der, i)
    s, _ = read_int(der, i)
    return r + s


def token(env):
    header = b64(json.dumps({"alg": "ES256", "kid": env["ASC_KEY_ID"], "typ": "JWT"}).encode())
    now = int(time.time())
    payload = b64(json.dumps({"iss": env["ASC_ISSUER_ID"], "iat": now, "exp": now + 1100,
                              "aud": "appstoreconnect-v1"}).encode())
    signing_input = f"{header}.{payload}".encode()
    der = subprocess.run(["openssl", "dgst", "-sha256", "-sign", env["ASC_KEY_PATH"]],
                         input=signing_input, capture_output=True, check=True).stdout
    return f"{header}.{payload}.{b64(der_to_raw(der))}"


def call(jwt, method, path, body=None):
    request = urllib.request.Request(API + path, method=method,
                                     data=json.dumps(body).encode() if body is not None else None)
    request.add_header("Authorization", f"Bearer {jwt}")
    request.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            raw = response.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as error:
        detail = error.read().decode(errors="replace")
        raise SystemExit(f"ERROR {method} {path} → {error.code}: {detail}")


def main():
    identifier, name = sys.argv[1], sys.argv[2]
    jwt = token(load_env())
    query = urllib.parse.urlencode({"filter[identifier]": identifier, "limit": 200})
    existing = [b for b in call(jwt, "GET", f"/v1/bundleIds?{query}")["data"]
                if b["attributes"]["identifier"] == identifier]
    if existing:
        print(f"Ya existe: {identifier} ({existing[0]['attributes']['name']})")
        return
    created = call(jwt, "POST", "/v1/bundleIds", {"data": {"type": "bundleIds", "attributes": {
        "identifier": identifier, "name": name, "platform": "IOS"}}})
    print(f"Registrado: {created['data']['attributes']['identifier']} ({created['data']['attributes']['name']})")


if __name__ == "__main__":
    main()
