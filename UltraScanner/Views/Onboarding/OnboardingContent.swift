import Foundation

/// Data for the 6-step tutorial, mirroring Main/Tutorial2-6.dc.html in the design canvas.
struct OnboardingSlide: Identifiable {
    let id: Int
    let systemImage: String
    let title: String
    let subtitle: String

    static let all: [OnboardingSlide] = [
        OnboardingSlide(
            id: 0, systemImage: "doc.viewfinder",
            title: String(localized: "Escanea cualquier documento en segundos"),
            subtitle: String(localized: "Convierte fotos en PDFs nítidos, con texto buscable, en un solo toque.")),
        OnboardingSlide(
            id: 1, systemImage: "doc.on.doc",
            title: String(localized: "Escanea varias páginas sin detenerte"),
            subtitle: String(localized: "El modo de lote detecta la siguiente hoja automáticamente y sigue capturando por ti, página tras página.")),
        OnboardingSlide(
            id: 2, systemImage: "pencil.and.scribble",
            title: String(localized: "Edita, firma y comparte al instante"),
            subtitle: String(localized: "Ajusta filtros, agrega tu firma y comparte el PDF listo por WhatsApp, correo o AirDrop.")),
        OnboardingSlide(
            id: 3, systemImage: "doc.text.magnifyingglass",
            title: String(localized: "Encuentra cualquier documento al instante"),
            subtitle: String(localized: "La búsqueda inteligente lee el texto de tus escaneos: busca \"factura marzo\" o \"contrato\" y aparece, aunque el archivo tenga otro nombre.")),
        OnboardingSlide(
            id: 4, systemImage: "rectangle.on.rectangle.angled",
            title: String(localized: "Separa o combina documentos cuando quieras"),
            subtitle: String(localized: "Divide un lote en varios documentos, o une páginas sueltas en uno solo, sin perder el orden ni volver a escanear.")),
        OnboardingSlide(
            id: 5, systemImage: "lock.shield",
            title: String(localized: "Tus documentos están protegidos"),
            subtitle: String(localized: "Todo se guarda cifrado en tu propio teléfono y solo esta app puede leerlo. Nunca se sube a ningún servidor: nadie más puede robar o ver tus documentos.")),
    ]
}
