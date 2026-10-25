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

## Anuncios

AdMob 12 + formulario de consentimiento de Google (UMP) + aviso de rastreo de Apple, igual que
UltraVocal (`Ads/AdManager.swift`). Un intersticial solo antes de abrir el menú de compartir. El
consentimiento se pide la primera vez que se comparte, no al abrir la app. Debug usa los IDs de
prueba de Google; Release, los de la cuenta (`project.yml`, app «UltraScanner», bloque
«Compartir documento»).

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

## Pendiente

- Capa de texto invisible "de verdad" en el PDF exportado (hoy va como anotación, `PDFGenerator`)
