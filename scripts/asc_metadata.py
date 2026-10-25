#!/usr/bin/env python3
"""Llena la ficha de UltraScanner en App Store Connect con la API (corre EN LA MAC MINI).
Adaptado de scripts/asc_metadata.py de UltraVocal.

    python3 asc_metadata.py metadata.json [--dry-run]

Lee la llave de API de ~/.appstoreconnect/asc.env (ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH); la
llave nunca sale de la Mac. Solo biblioteca estándar + openssl (para firmar el token ES256).

SOLO toca la app mx.com.claudita.ultrascanner.

Llena: categorías, nombre/subtítulo y URL de privacidad por idioma, clasificación por edad (todo
«ninguno» salvo anuncios: sí), versión y copyright, descripción/palabras clave/texto
promocional/URL de soporte por idioma, la información para la revisión, capturas si las hay y, con
"price": "free", precio 0 y disponibilidad en todos los países menos los de "excludeTerritories"
(China: la tienda china exige licencia ICP). No toca la etiqueta de privacidad (no está en la API).
"""
import base64
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request

API = "https://api.appstoreconnect.apple.com"
ALLOWED_BUNDLE = "mx.com.claudita.ultrascanner"
DRY_RUN = "--dry-run" in sys.argv


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


class Client:
    def __init__(self, env):
        self.env = env
        self.jwt = token(env)
        self.errors = []

    def call(self, method, path, body=None):
        if DRY_RUN and method != "GET":
            print(f"   [simulado] {method} {path}")
            return {}
        request = urllib.request.Request(API + path, method=method,
                                         data=json.dumps(body).encode() if body is not None else None)
        request.add_header("Authorization", f"Bearer {self.jwt}")
        request.add_header("Content-Type", "application/json")
        for attempt in range(4):
            try:
                with urllib.request.urlopen(request, timeout=60) as response:
                    raw = response.read()
                    return json.loads(raw) if raw else {}
            except urllib.error.HTTPError as error:
                # Errores pasajeros de Apple (5xx): reintentar con espera creciente.
                if error.code >= 500 and attempt < 3:
                    time.sleep(3 * (attempt + 1))
                    continue
                return self._failed(method, path, error)

    def _failed(self, method, path, error):
        detail = error.read().decode(errors="replace")
        try:
            errors = json.loads(detail).get("errors", [])
            detail = " | ".join(f"{e.get('title')}: {e.get('detail')}" for e in errors) or detail
        except ValueError:
            pass
        message = f"{method} {path} → {error.code}: {detail}"
        if method == "GET":
            raise SystemExit("ERROR " + message)
        print("   ERROR", message)
        self.errors.append(message)
        return None


def upsert_localizations(client, existing, locales, make_attributes, create_type, parent_rel, parent_type, parent_id):
    """PATCH a las localizaciones que ya existen y POST a las que faltan."""
    by_locale = {item["attributes"]["locale"]: item for item in existing}
    for locale, fields in locales.items():
        attributes = {k: v for k, v in make_attributes(fields).items() if v}
        if locale in by_locale:
            item = by_locale[locale]
            print(f"   {locale}: actualizando {', '.join(attributes)}")
            client.call("PATCH", f"/v1/{create_type}/{item['id']}",
                        {"data": {"type": create_type, "id": item["id"], "attributes": attributes}})
        else:
            print(f"   {locale}: creando ({', '.join(attributes)})")
            client.call("POST", f"/v1/{create_type}", {"data": {
                "type": create_type,
                "attributes": {"locale": locale, **attributes},
                "relationships": {parent_rel: {"data": {"type": parent_type, "id": parent_id}}},
            }})


def set_free(client, app_id, excluded=()):
    """Precio 0 (precio base en EE. UU.) y disponible en todos los países menos `excluded`."""
    print("==> Precio: gratis")
    points = client.call("GET", f"/v1/apps/{app_id}/appPricePoints?filter[territory]=USA&limit=200")["data"]
    free = next((p for p in points if float(p["attributes"].get("customerPrice") or 0) == 0), None)
    if not free:
        print("   ERROR: no encontré el punto de precio 0")
        client.errors.append("precio 0")
        return
    client.call("POST", "/v1/appPriceSchedules", {
        "data": {"type": "appPriceSchedules", "relationships": {
            "app": {"data": {"type": "apps", "id": app_id}},
            "baseTerritory": {"data": {"type": "territories", "id": "USA"}},
            "manualPrices": {"data": [{"type": "appPrices", "id": "${precio-gratis}"}]},
        }},
        "included": [{"type": "appPrices", "id": "${precio-gratis}", "attributes": {"startDate": None},
                      "relationships": {"appPricePoint": {"data": {"type": "appPricePoints", "id": free["id"]}}}}],
    })

    print("==> Disponibilidad: todos los países" + (f" menos {', '.join(excluded)}" if excluded else ""))
    # Apple exige todos los países en la petición: los excluidos van con "available": false.
    territories = client.call("GET", "/v1/territories?limit=200")["data"]
    try:
        current = client.call("GET", f"/v1/apps/{app_id}/appAvailabilityV2").get("data")
    except SystemExit:
        current = None
    if current:
        print("   ya está definida; se deja como está (cámbiala en Precio y disponibilidad si hace falta)")
        return
    client.call("POST", "/v2/appAvailabilities", {
        # Países nuevos que agregue Apple: no automáticos, para no caer sin querer en uno excluido.
        "data": {"type": "appAvailabilities", "attributes": {"availableInNewTerritories": not excluded}, "relationships": {
            "app": {"data": {"type": "apps", "id": app_id}},
            "territoryAvailabilities": {"data": [{"type": "territoryAvailabilities", "id": f"${{{t['id']}}}"} for t in territories]},
        }},
        "included": [{"type": "territoryAvailabilities", "id": f"${{{t['id']}}}",
                      "attributes": {"available": t["id"] not in excluded},
                      "relationships": {"territory": {"data": {"type": "territories", "id": t["id"]}}}}
                     for t in territories],
    })


def put_bytes(url, headers, data):
    """Sube un trozo de archivo a la URL que da Apple (sin el token de la API)."""
    request = urllib.request.Request(url, method="PUT", data=data)
    for header in headers or []:
        request.add_header(header["name"], header["value"])
    with urllib.request.urlopen(request, timeout=120) as response:
        response.read()


def upload_screenshots(client, version_id, root, media_from=None):
    """Reemplaza las capturas de iPhone de cada idioma con los PNG de <root>/<locale>/ (en orden)."""
    import glob
    import hashlib
    locs = client.call("GET", f"/v1/appStoreVersions/{version_id}/appStoreVersionLocalizations")["data"]
    for loc in locs:
        locale = loc["attributes"]["locale"]
        source = (media_from or {}).get(locale, locale)  # es-ES usa las de es-MX, en-GB las de en-US
        files = sorted(glob.glob(os.path.join(root, source, "*.png")))
        if not files:
            continue
        print(f"==> Capturas {locale}: {len(files)}")
        sets = client.call("GET", f"/v1/appStoreVersionLocalizations/{loc['id']}/appScreenshotSets")["data"]
        target = next((x for x in sets if x["attributes"]["screenshotDisplayType"] == "APP_IPHONE_67"), None)
        if target:
            for old in client.call("GET", f"/v1/appScreenshotSets/{target['id']}/appScreenshots")["data"]:
                client.call("DELETE", f"/v1/appScreenshots/{old['id']}")
        elif DRY_RUN:
            print("   [simulado] se crearía el grupo de capturas de iPhone de 6.9\"")
            continue
        else:
            # Las de 6.9" (1320 × 2868) van en APP_IPHONE_67: la API no tiene un tipo propio para 6.9".
            for display in ("APP_IPHONE_67",):
                errors_before = len(client.errors)
                created = client.call("POST", "/v1/appScreenshotSets", {"data": {
                    "type": "appScreenshotSets", "attributes": {"screenshotDisplayType": display},
                    "relationships": {"appStoreVersionLocalization": {"data": {"type": "appStoreVersionLocalizations", "id": loc["id"]}}},
                }})
                if created:
                    target = created["data"]
                    break
                # Ese tipo no existe en la API: se prueba el siguiente sin contarlo como error.
                del client.errors[errors_before:]
            if not target:
                client.errors.append(f"no se pudo crear el grupo de capturas de {locale}")
                continue
        print(f"   tipo {target['attributes']['screenshotDisplayType']}")
        if DRY_RUN:
            continue
        for path in files:
            data = open(path, "rb").read()
            created = client.call("POST", "/v1/appScreenshots", {"data": {
                "type": "appScreenshots",
                "attributes": {"fileName": os.path.basename(path), "fileSize": len(data)},
                "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": target["id"]}}},
            }})
            if not created:
                continue
            shot = created["data"]
            for op in shot["attributes"]["uploadOperations"]:
                put_bytes(op["url"], op.get("requestHeaders"), data[op["offset"]:op["offset"] + op["length"]])
            client.call("PATCH", f"/v1/appScreenshots/{shot['id']}", {"data": {
                "type": "appScreenshots", "id": shot["id"],
                "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()},
            }})
            print(f"   subida {os.path.basename(path)}")
        # Apple las procesa unos segundos después de subirlas.
        for _ in range(20):
            time.sleep(3)
            shots = client.call("GET", f"/v1/appScreenshotSets/{target['id']}/appScreenshots")["data"]
            states = [x["attributes"].get("assetDeliveryState", {}).get("state") for x in shots]
            if all(state in ("COMPLETE", "FAILED") for state in states):
                break
        for shot in shots:
            delivery = shot["attributes"].get("assetDeliveryState", {})
            line = f"   {shot['attributes']['fileName']}: {delivery.get('state')}"
            if delivery.get("errors"):
                line += " — " + "; ".join(e.get("description", "") for e in delivery["errors"])
                client.errors.append(line.strip())
            print(line)


def upload_previews(client, version_id, root, media_from=None):
    """Reemplaza el video de muestra de iPhone de cada idioma con <root>/<locale>/UltraScanner-<locale>.mp4."""
    import hashlib
    locs = client.call("GET", f"/v1/appStoreVersions/{version_id}/appStoreVersionLocalizations")["data"]
    for loc in locs:
        locale = loc["attributes"]["locale"]
        source = (media_from or {}).get(locale, locale)
        path = os.path.join(root, source, f"UltraScanner-{source}.mp4")
        if not os.path.exists(path):
            continue
        print(f"==> Video de muestra {locale}")
        sets = client.call("GET", f"/v1/appStoreVersionLocalizations/{loc['id']}/appPreviewSets")["data"]
        target = next((x for x in sets if x["attributes"]["previewType"] == "IPHONE_67"), None)
        if target:
            for old in client.call("GET", f"/v1/appPreviewSets/{target['id']}/appPreviews")["data"]:
                client.call("DELETE", f"/v1/appPreviews/{old['id']}")
        elif DRY_RUN:
            print("   [simulado] se crearía el grupo de videos de iPhone de 6.9\"")
            continue
        else:
            created = client.call("POST", "/v1/appPreviewSets", {"data": {
                "type": "appPreviewSets", "attributes": {"previewType": "IPHONE_67"},
                "relationships": {"appStoreVersionLocalization": {"data": {"type": "appStoreVersionLocalizations", "id": loc["id"]}}},
            }})
            if not created:
                continue
            target = created["data"]
        if DRY_RUN:
            continue
        data = open(path, "rb").read()
        created = client.call("POST", "/v1/appPreviews", {"data": {
            "type": "appPreviews",
            "attributes": {"fileName": os.path.basename(path), "fileSize": len(data), "mimeType": "video/mp4",
                           "previewFrameTimeCode": "00:00:12:00"},
            "relationships": {"appPreviewSet": {"data": {"type": "appPreviewSets", "id": target["id"]}}},
        }})
        if not created:
            continue
        preview = created["data"]
        for op in preview["attributes"]["uploadOperations"]:
            put_bytes(op["url"], op.get("requestHeaders"), data[op["offset"]:op["offset"] + op["length"]])
        client.call("PATCH", f"/v1/appPreviews/{preview['id']}", {"data": {
            "type": "appPreviews", "id": preview["id"],
            "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()},
        }})
        print(f"   subido {os.path.basename(path)} ({len(data) // 1024} KB); Apple lo procesa…")
        # El video tarda más que una imagen: se espera hasta ~3 min.
        state = None
        for _ in range(60):
            time.sleep(3)
            current = client.call("GET", f"/v1/appPreviews/{preview['id']}")["data"]["attributes"]
            delivery = current.get("assetDeliveryState") or {}
            video = current.get("videoDeliveryState") or {}
            state = video.get("state") or delivery.get("state")
            if state in ("COMPLETE", "FAILED"):
                errors = (video.get("errors") or []) + (delivery.get("errors") or [])
                if errors:
                    message = f"video {locale}: " + "; ".join(e.get("description", "") for e in errors)
                    print("   ERROR", message)
                    client.errors.append(message)
                break
        print(f"   estado: {state}")


def main():
    meta = json.load(open(sys.argv[1], encoding="utf-8"))
    if meta["bundleId"] != ALLOWED_BUNDLE:
        raise SystemExit(f"ALTO: este script solo llena {ALLOWED_BUNDLE}.")
    client = Client(load_env())

    apps = client.call("GET", f"/v1/apps?filter[bundleId]={ALLOWED_BUNDLE}")["data"]
    if not apps:
        raise SystemExit(f"No hay app con el bundle {ALLOWED_BUNDLE} en App Store Connect.")
    app = apps[0]
    print(f"==> App: {app['attributes']['name']} ({app['id']}), idioma principal {app['attributes']['primaryLocale']}")

    # --- Información de la app (la editable: la que no está a la venta) -----------------------
    infos = client.call("GET", f"/v1/apps/{app['id']}/appInfos")["data"]
    info = next((i for i in infos if i["attributes"].get("state", i["attributes"].get("appStoreState"))
                 not in ("READY_FOR_DISTRIBUTION", "READY_FOR_SALE")), infos[0])
    print(f"==> Categorías: {meta['primaryCategory']} / {meta['secondaryCategory']}")
    client.call("PATCH", f"/v1/appInfos/{info['id']}", {"data": {"type": "appInfos", "id": info["id"], "relationships": {
        "primaryCategory": {"data": {"type": "appCategories", "id": meta["primaryCategory"]}},
        "secondaryCategory": {"data": {"type": "appCategories", "id": meta["secondaryCategory"]}},
    }}})

    print("==> Nombre y subtítulo por idioma")
    info_locs = client.call("GET", f"/v1/appInfos/{info['id']}/appInfoLocalizations")["data"]
    upsert_localizations(
        client, info_locs, meta["localizations"],
        lambda f: {"name": f["name"], "subtitle": f["subtitle"], "privacyPolicyUrl": meta.get("privacyPolicyUrl")},
        "appInfoLocalizations", "appInfo", "appInfos", info["id"],
    )

    print("==> Clasificación por edad: todo «ninguno» salvo anuncios (sí)")
    rating = client.call("GET", f"/v1/appInfos/{info['id']}/ageRatingDeclaration")["data"]
    attributes = {}
    for key, value in rating["attributes"].items():
        # Solo las preguntas de contenido: nada de clasificaciones por país, banda infantil ni URLs.
        if any(part in key for part in ("Override", "Classification", "grac", "Url", "kidsAgeBand")):
            continue
        if key == "advertising":
            attributes[key] = bool(meta.get("containsAds"))
        elif isinstance(value, bool) or key in ("gambling", "unrestrictedWebAccess", "lootBox", "messagingAndChat",
                                              "userGeneratedContent", "parentalControls", "ageAssurance",
                                              "advertising", "healthOrWellnessTopics", "seventeenPlus",
                                              "socialMedia", "socialMediaAgeRestricted"):
            attributes[key] = False
        else:
            attributes[key] = "NONE"
    client.call("PATCH", f"/v1/ageRatingDeclarations/{rating['id']}",
                {"data": {"type": "ageRatingDeclarations", "id": rating["id"], "attributes": attributes}})

    # --- Versión ------------------------------------------------------------------------------
    versions = client.call("GET", f"/v1/apps/{app['id']}/appStoreVersions?filter[platform]=IOS")["data"]
    editable = [v for v in versions if v["attributes"].get("appStoreState") in
                ("PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED")]
    if not editable:
        raise SystemExit("No hay una versión en preparación para editar.")
    version = editable[0]
    print(f"==> Versión {version['attributes']['versionString']} → {meta['versionString']}, copyright")
    client.call("PATCH", f"/v1/appStoreVersions/{version['id']}", {"data": {
        "type": "appStoreVersions", "id": version["id"],
        "attributes": {"versionString": meta["versionString"], "copyright": meta["copyright"]},
    }})

    print("==> Descripción, palabras clave y texto promocional por idioma")
    version_locs = client.call("GET", f"/v1/appStoreVersions/{version['id']}/appStoreVersionLocalizations")["data"]
    upsert_localizations(
        client, version_locs, meta["localizations"],
        lambda f: {"description": f["description"], "keywords": f["keywords"],
                   "promotionalText": f["promotionalText"], "supportUrl": meta.get("supportUrl"),
                   "marketingUrl": meta.get("marketingUrl")},
        "appStoreVersionLocalizations", "appStoreVersion", "appStoreVersions", version["id"],
    )

    print("==> Información para la revisión")
    review = {"notes": meta["reviewNotes"], "demoAccountRequired": False}
    contact = meta.get("reviewContact") or {}
    for key in ("contactFirstName", "contactLastName", "contactPhone", "contactEmail"):
        if contact.get(key):
            review[key] = contact[key]
    current = client.call("GET", f"/v1/appStoreVersions/{version['id']}/appStoreReviewDetail").get("data")
    if current and not contact:
        # Para editarla, Apple exige el contacto completo; las notas ya quedaron al crearla.
        print("   ya existe; se actualiza cuando esté el contacto en metadata.json")
    elif current:
        client.call("PATCH", f"/v1/appStoreReviewDetails/{current['id']}",
                    {"data": {"type": "appStoreReviewDetails", "id": current["id"], "attributes": review}})
    else:
        client.call("POST", "/v1/appStoreReviewDetails", {"data": {
            "type": "appStoreReviewDetails", "attributes": review,
            "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": version["id"]}}},
        }})

    if meta.get("screenshots"):
        upload_screenshots(client, version["id"], os.path.join(os.path.dirname(os.path.abspath(sys.argv[1])), meta["screenshots"]), meta.get("mediaFrom"))

    if meta.get("previews"):
        upload_previews(client, version["id"], os.path.join(os.path.dirname(os.path.abspath(sys.argv[1])), meta["previews"]), meta.get("mediaFrom"))

    if meta.get("price") == "free":
        set_free(client, app["id"], tuple(meta.get("excludeTerritories", [])))

    pending = [name for name, value in (("URL de soporte", meta.get("supportUrl")),
                                        ("URL de política de privacidad", meta.get("privacyPolicyUrl")),
                                        ("contacto para la revisión", meta.get("reviewContact"))) if not value]
    print()
    if DRY_RUN:
        print("Simulación: no se cambió nada en App Store Connect.")
    elif client.errors:
        print(f"Terminó con {len(client.errors)} error(es): revisa los mensajes de arriba.")
    else:
        print("Listo: todo lo anterior quedó guardado en App Store Connect.")
    if pending:
        print("Falta (aún no está en metadata.json): " + ", ".join(pending) + ".")
    print("A mano en App Store Connect: etiqueta de privacidad (ver AppStore/privacidad-app-store.md).")
    sys.exit(1 if client.errors else 0)


if __name__ == "__main__":
    main()
