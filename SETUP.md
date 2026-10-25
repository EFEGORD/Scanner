# UltraScanner

App de escaneo de documentos para iOS (Swift/SwiftUI), 100% local: nada sale del teléfono,
todo se guarda cifrado, sin cuentas ni premium (un anuncio intersticial solo al compartir). El diseño de las pantallas vive en el canvas "Flujo Scanner App".

## Compilar e instalar (desde Windows, Git Bash)

El proyecto Xcode no se versiona: lo genera XcodeGen a partir de `project.yml` en la Mac mini.

```bash
scripts/deploy-ios.sh           # compila en la Mac mini e instala en el iPhone "EFE"
scripts/deploy-ios.sh test      # pruebas automáticas en el simulador
scripts/deploy-ios.sh sim       # solo compila para el simulador
```

`deploy-ios.sh` copia el árbol de trabajo a `~/Documents/UltraScanner` en la Mac por SSH. La
firma solo funciona dentro de la sesión gráfica de la Mac: si el agente de UltraVocal está
corriendo (`UltraVocalApp/scripts/deploy-ios.sh agente`), instala sin contraseña; si no, pide
la contraseña de sudo de la Mac. Firma con la llave de App Store Connect
(`~/.appstoreconnect/asc.env` en la Mac), así que no hace falta cuenta en Xcode.

Ícono: `Design/scripts/logo_ultrascanner.py` (VectorCraft) genera las propuestas en
`Design/logo-propuestas/`; la elegida (A) está en `UltraScanner/Assets.xcassets/AppIcon.appiconset`.

## Qué hace la app

- Tutorial de 6 pantallas + permiso de cámara (`Views/Onboarding/`, `Views/Permissions/`)
- Escanear con VisionKit (bordes y lote automáticos) → revisar (mover/eliminar páginas) →
  editar → guardar (nombre sugerido por OCR, carpeta) → anuncio
- Editar (`Views/Edit/PageEditorView.swift`): filtros Original/Color/Blanco y negro/Magia,
  rotar, firma con el dedo (se puede mover, agrandar y guardar para reusarla). Sirve para un
  escaneo nuevo y para un documento ya guardado.
- Biblioteca con buscador por el texto de los documentos (OCR + FTS5), carpetas, estado vacío
- Visor: páginas, renombrar, mover a carpeta, eliminar, dividir, editar, combinar, compartir
- Combinar (`Views/Combine/`): buscar o explorar, añadir documentos completos o páginas
  sueltas, escanear páginas nuevas, ordenar y guardar como documento nuevo. Los originales no
  se modifican (sus archivos cifrados se copian).
- Compartir PDF/JPG con el menú nativo de iOS; el archivo temporal se borra al cerrarlo
- Ajustes: Face ID, formato al compartir, carpetas, firma guardada, espacio usado, cámara
- OCR siempre en [idioma del teléfono + inglés], sin selector

Bundle ID: `mx.com.claudita.ultrascanner` (registrado con `scripts/asc_bundle_id.py`). El
nombre del servicio del Keychain (`EncryptionManager.service`) no debe cambiar nunca: sin él, los
documentos guardados quedan ilegibles.

## Idiomas

La app se escribe en español (idioma de desarrollo) y trae inglés en
`UltraScanner/Localizable.xcstrings` (textos) y `UltraScanner/InfoPlist.xcstrings` (permisos).
Los textos armados en código van con `String(localized:)`; en las vistas, los literales de
`Text`/`Button`/etc. ya se traducen solos. Al agregar o cambiar textos:

    scripts/deploy-ios.sh sim
    scripts/check-strings.sh      # lista los que faltan en el catálogo y los que ya no se usan

## Sitio web (UltraTools)

https://ultratools.claudita.com.mx agrupa las apps: portada, `/ultrascanner/` (inicio, `soporte`
y `privacidad`, las URLs de la ficha del App Store) y `/app-ads.txt` de AdMob. Corre en el
nginx con Docker de la Mac mini (`~/Documents/NGINX`), con certificado de Let's Encrypt que
renueva el contenedor `certbot` (cada 12 h); el contenedor `nginx` se recarga solo cada 6 h para
tomar los certificados renovados (`command` en `~/Documents/NGINX/docker-compose.yml`). `/ultravocal/` sirve la carpeta del sitio de UltraVocal tal
cual; `ultravocal.claudita.com.mx` sigue igual. El registro DNS lo mantiene el contenedor
`cloudflare-ddns` (lista `DOMAINS` de `~/Documents/NGINX/cloudflare/docker-compose.yml`).

- Páginas: `web/ultratools/`. Para publicarlas: `scripts/site-deploy.sh`.
- Configuración de nginx: `web/nginx/ultratools.claudita.com.mx.conf` (se copió a mano a
  `~/Documents/NGINX/nginx/conf.d/`; si cambia, cópiala y recarga con
  `docker exec nginx nginx -t && docker exec nginx nginx -s reload`).

## Anuncios

AdMob 12 + formulario de consentimiento de Google (UMP) + aviso de rastreo de Apple, igual que
UltraVocal (`Ads/AdManager.swift`). Un intersticial solo antes de abrir el menú de compartir. El
consentimiento se pide la primera vez que se comparte, no al abrir la app. Debug usa los IDs de
prueba de Google; Release, los de la cuenta (`project.yml`, app «UltraScanner», bloque
«Compartir documento»).

## Estadísticas de uso (Firebase Analytics)

`Analytics/AppAnalytics.swift` manda a Firebase solo qué funciones se usan (escaneo guardado y
cuántas páginas, edición, compartir y formato, combinar, dividir, búsqueda usada, carpeta creada,
fin del tutorial, bloqueo con Face ID). Nunca títulos, texto de los documentos, palabras buscadas
ni nombres de carpetas. Respeta el mismo formulario de consentimiento de Google que los anuncios
(modo de consentimiento: negado hasta saber; ver `project.yml`).

- Necesita `UltraScanner/GoogleService-Info.plist` (consola de Firebase › proyecto › app de iOS
  `mx.com.claudita.ultrascanner`). **No está en git**: cópialo a mano en un clon nuevo. Sin él la
  app funciona pero no manda nada, y `mac-appstore.sh` no deja subirla.
- En Debug no manda nada salvo con `-USAnalytics YES` (y nunca en el modo demo). Para ver los
  eventos en vivo: `-USAnalytics YES -FIRDebugEnabled` y Firebase › DebugView.

## Seguridad

- Imágenes de las páginas y firma: AES-GCM (CryptoKit) con una llave en el Keychain
  (`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`) + protección de archivos de iOS.
- Base de datos (títulos, carpetas, texto OCR e índice del buscador): en **Release** va cifrada
  completa con SQLCipher (fork `sqlcipher/GRDB.swift`), con una llave del Keychain que no sale
  del teléfono, y los datos se excluyen de los respaldos. Una base sin cifrar de una versión
  anterior se migra sola al primer arranque (`DatabaseManager.encryptPlaintextDatabase`).
- En **Debug** la base de datos queda sin cifrar a propósito, para poder revisarla al depurar
  (si el teléfono ya tiene una cifrada por Release, Debug la abre con la llave).
- Decisión de producto: no hay respaldo ni "exportar todo". Si se pierde el teléfono, se
  pierden los documentos.

## Publicar en la App Store

    scripts/screenshots.sh         # capturas 6.9" es/en con documentos ficticios (modo demo, solo Debug)
    scripts/appstore-metadata.sh   # ficha, capturas, precio y disponibilidad (AppStore/metadata.json)
    scripts/appstore-upload.sh     # pruebas, archivo Release y subida a TestFlight

- El modo demo (`Demo/DemoMode.swift`, `-USDemo YES -USScreen library|search|viewer|combine|security`)
  llena la biblioteca con documentos dibujados en la app y pasados por el OCR real. Solo existe
  en Debug; `mac-appstore.sh` se detiene si aparece en el binario de Release.
- La subida firma con el certificado «Apple Distribution» del llavero de la Mac y el perfil
  «UltraScanner App Store» (`scripts/asc_profile.py`, vence 2027-10-16). Usa el agente de
  UltraVocal (`mac-build.sh appstore <compilación>`); sin agente, pide la contraseña de sudo.
- A mano en App Store Connect: etiqueta de privacidad (`AppStore/privacidad-app-store.md`),
  elegir la compilación en la versión y enviarla a revisión.

## Pendiente

- Capa de texto invisible "de verdad" en el PDF exportado (hoy va como anotación, `PDFGenerator`)
