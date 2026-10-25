# Scanner — guía de arranque en Xcode (Mac mini)

Este repo trae el código Swift ya escrito, pero **no** el archivo `.xcodeproj` — eso hay
que generarlo en la Mac con Xcode (es más seguro que escribirlo a mano, se corrompe fácil).

## 1. Crear el proyecto en Xcode

1. Xcode → File → New → Project → **App**.
2. Product Name: `Scanner`. Interface: **SwiftUI**. Language: **Swift**. Sin Core Data,
   sin Tests (los agregamos después si quieres).
3. Guarda el proyecto en la raíz de este repo, **sobrescribiendo** la carpeta `Scanner/`
   que Xcode crea por defecto — o mejor, bórrala y en su lugar arrastra la carpeta
   `Scanner/` que ya viene en este repo (botón derecho en el navigator → "Add Files to
   Scanner…", marca "Copy items if needed" DESMARCADO y "Create groups").
4. Borra el `ContentView.swift` y el `Item.swift`/Core Data que Xcode genera por defecto
   si no los usamos (no los usamos).
5. El `@main` ya está en `App/ScannerApp.swift` — asegúrate de que sea el único `@main`
   del proyecto (borra el `ScannerApp.swift` que Xcode generó por defecto si quedó duplicado).

## 2. Dependencias (Swift Package Manager)

En Xcode: File → Add Package Dependencies…

| Paquete | URL | Para qué |
|---|---|---|
| GRDB.swift | `https://github.com/groue/GRDB.swift` | Acceso a SQLite (documentos, páginas, búsqueda FTS5) |
| Google Mobile Ads SDK | `https://github.com/googleads/swift-package-manager-google-mobile-ads` | El anuncio intersticial al guardar/compartir |

No se necesita nada más — VisionKit, Vision, PDFKit, CryptoKit, LocalAuthentication y
Security son frameworks del sistema, no paquetes.

## 3. Info.plist — permisos obligatorios

Sin esto la app truena al pedir cámara o Face ID. Agrega estas claves (Target → Info):

- `NSCameraUsageDescription` → "Scanner necesita la cámara para escanear tus documentos."
- `NSFaceIDUsageDescription` → "Usamos Face ID para que solo tú puedas abrir tus documentos."
- `GADApplicationIdentifier` → el App ID de AdMob (usa el de prueba de Google mientras
  no tengas el tuyo: `ca-app-pub-3940256099942544~1458002511`).

## 4. Cifrado de la base de datos (SQLCipher) — pendiente, opcional por ahora

`Data/DatabaseManager.swift` deja la base de datos protegida con **Data Protection de
iOS** (`NSFileProtectionCompleteUnlessOpen`) desde ya — eso ya cifra el archivo atado al
passcode del teléfono. Para la segunda capa que platicamos (cifrado de app, con
SQLCipher, independiente del passcode del sistema):

1. Reemplaza la dependencia GRDB.swift normal por la variante con SQLCipher — GRDB
   documenta esto en su README bajo "Encryption" (necesita compilar sqlite3 con
   `SQLITE_HAS_CODEC` enlazado contra SQLCipher; lo más simple hoy es usar el pod/paquete
   `GRDB.swift/SQLCipher` o `SQLCipher` + un build custom — es más trabajo de setup que
   el resto del proyecto junto).
2. Una vez enlazado, en `DatabaseManager.swift` descomenta/agrega:
   ```swift
   config.prepareDatabase { db in
       try db.usePassphrase(try EncryptionManager.shared.databasePassphrase())
   }
   ```
   `EncryptionManager.databasePassphrase()` ya existe y genera/guarda esa clave en el
   Keychain (`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`), lista para usarse.

No bloquea poder compilar y correr la app — es una mejora de seguridad que se agrega
después sin tocar el resto del código.

## 5. Qué ya está completo vs. qué es un primer borrador

**Completo y funcional (en teoría — nunca compilado, revisar al primer build):**
- Modelos (`Models/`), capa de base de datos + FTS5 (`Data/`)
- Cifrado de archivos (imágenes/thumbnails) con AES-GCM + Keychain (`Security/`)
- Bloqueo con Face ID (`Security/AppLockManager.swift`)
- Wrapper de VisionKit para escanear (`Scanning/`)
- OCR multiidioma automático [idioma del teléfono + inglés] (`OCR/`)
- Flujo de Onboarding (6 pantallas, dots, Omitir) (`Views/Onboarding/`)
- Biblioteca con carpetas, lista de documentos, FAB de escanear (`Views/Library/`)
- Captura → Revisión → Guardar (pipeline completo cámara→OCR→cifrado→BD)

**Primer borrador, falta terminar (funcional pero simplificado):**
- `DocumentEditView` — falta: filtros (color/B&N/magia), rotar, recortar, firma (PencilKit)
- `ExportView` — el share sheet real (`buildShareFile()`) está vacío: falta descifrar
  páginas, generar el PDF con `PDFGenerator`, escribir el archivo temporal, y borrarlo
  después de compartir
- `CombineDocumentsView` — la búsqueda ya funciona; falta la bandeja de "páginas
  agregadas" y el botón de guardar el documento combinado (usa
  `DocumentRepository.mergePages`)
- Pantalla de "Dividir en 2 documentos" dentro de un documento ya guardado (usa
  `DocumentRepository.splitDocument`, aún no tiene UI)

Ninguna de estas piezas faltantes requiere red ni servidor — todo sigue siendo local.

## 6. Primer build

1. Abre el proyecto, selecciona un simulador de iPhone (el escáner de VisionKit **no
   funciona en el Simulator** — para probar la cámara real necesitas un iPhone físico
   conectado a la Mac mini).
2. Build (⌘B). Lo más probable es que el primer intento tenga 2-3 errores menores de
   nombres/imports — son normales en código escrito sin compilador a la mano; dime el
   error exacto y lo corregimos.
