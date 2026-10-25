# Etiqueta de privacidad (App Store Connect › Privacidad de la app)

Apple no la expone en la API: se llena a mano una vez. La app **no** recopila nada propio (los
documentos nunca salen del iPhone); lo que se declara es lo que recopilan los SDK de Google:
AdMob (anuncios, developers.google.com/admob/ios/privacy/data-disclosure) y Firebase Analytics
(uso de la app, firebase.google.com/docs/ios/app-store-data-collection).

1. **¿Recopilas datos de esta app?** → Sí, recopilamos datos de esta app.
2. Tipos de datos (marca solo estos):

| Categoría › Tipo | Uso | ¿Vinculado al usuario? | ¿Para rastreo? |
|---|---|---|---|
| Ubicación › Ubicación aproximada (por IP) | Publicidad de terceros, Analíticas | No | No |
| Identificadores › ID del dispositivo | Publicidad de terceros, Analíticas | No | **Sí** |
| Datos de uso › Interacción con el producto | Publicidad de terceros, Analíticas | No | No |
| Datos de uso › Datos de publicidad | Publicidad de terceros | No | **Sí** |
| Diagnóstico › Datos de fallos | Analíticas | No | No |
| Diagnóstico › Datos de rendimiento | Analíticas | No | No |
| Diagnóstico › Otros datos de diagnóstico | Analíticas | No | No |

3. **No** marques: contenido del usuario (fotos, documentos), historial de búsqueda, contactos,
   información financiera, salud, nombre, correo ni ID de usuario. Nada de eso sale del
   teléfono: Firebase solo recibe eventos como "escaneó 3 páginas" (`Analytics/AppAnalytics.swift`),
   nunca títulos, texto de los documentos ni lo que se escribe en la búsqueda.
4. El "rastreo" solo ocurre si el usuario lo permite en el aviso de iOS (App Tracking
   Transparency) que la app muestra la primera vez que comparte.

URL de la política de privacidad: https://ultratools.claudita.com.mx/ultrascanner/privacidad
