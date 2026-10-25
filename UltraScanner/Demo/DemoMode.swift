#if DEBUG
import UIKit

/// Demo mode for the App Store screenshots (scripts/screenshots.sh), only in Debug:
///
///   -USDemo YES -USScreen library|search|viewer|combine|security
///
/// Fills an empty library with fictitious documents in the phone's language (Spanish or
/// English), drawn here and saved through the real pipeline (OCR, document type, encryption),
/// skips onboarding and the Face ID lock, and opens the requested screen.
enum DemoMode {
    static var isActive: Bool { UserDefaults.standard.bool(forKey: "USDemo") }
    static var screen: String { UserDefaults.standard.string(forKey: "USScreen") ?? "library" }

    private static var isSpanish: Bool { Locale.preferredLanguages.first?.hasPrefix("es") ?? true }

    static var searchQuery: String { isSpanish ? "identificación" : "ID" }

    static var idTitle: String { isSpanish ? "INE" : "Driver license" }
    static var billTitle: String { isSpanish ? "Recibo del agua octubre" : "Electric bill October" }
    static var leaseTitle: String { isSpanish ? "Contrato de arrendamiento" : "Lease agreement" }

    static func document(titled title: String) -> ScanDocument? {
        try? DocumentRepository.shared.allDocuments().first { $0.title == title }
    }

    /// Seeds the library once (the script reinstalls the app for each language).
    static func prepare() async {
        let repository = DocumentRepository.shared
        guard (try? repository.allDocuments().isEmpty) ?? false else { return }
        let samples = isSpanish ? spanishSamples : englishSamples
        var folderIds: [String: String] = [:]
        for name in samples.map(\.folder) where folderIds[name] == nil {
            folderIds[name] = try? repository.createFolder(name: name).id
        }
        // Oldest first: the library lists the most recent on top.
        for sample in samples.reversed() {
            var pages: [ScanPage] = []
            for (position, image) in sample.pages.enumerated() {
                if let page = try? await PageFactory.makePage(from: image, position: position) {
                    pages.append(page)
                }
            }
            _ = try? repository.createDocument(title: sample.title, folderId: folderIds[sample.folder], pages: pages)
        }
    }

    // MARK: - Samples (fictitious people, numbers and companies)

    private struct Sample {
        let title: String
        let folder: String
        let pages: [UIImage]
    }

    private static var spanishSamples: [Sample] {
        [
            Sample(title: "Contrato de arrendamiento", folder: "Casa", pages: [letter(
                heading: "CONTRATO DE ARRENDAMIENTO",
                lines: ["Que celebran por una parte Ana Torres Ruiz, en lo sucesivo EL ARRENDADOR,",
                        "y por la otra Juan Pérez López, en lo sucesivo EL ARRENDATARIO.",
                        "",
                        "PRIMERA. El arrendador da en arrendamiento el departamento ubicado en",
                        "Calle Ejemplo 123, Col. Centro, por un plazo de doce meses.",
                        "SEGUNDA. La renta mensual será de $9,500.00, pagadera los primeros",
                        "cinco días de cada mes.",
                        "TERCERA. El arrendatario entrega un depósito equivalente a un mes de renta.",
                        "CUARTA. Los servicios de agua, luz e internet corren por cuenta",
                        "del arrendatario."],
                signers: ["EL ARRENDADOR", "EL ARRENDATARIO"])]),
            Sample(title: "INE", folder: "Identificaciones", pages: [
                card(color: UIColor(red: 0.93, green: 0.88, blue: 0.95, alpha: 1),
                     lines: ["INSTITUTO NACIONAL ELECTORAL", "MÉXICO · CREDENCIAL PARA VOTAR",
                             "NOMBRE", "PÉREZ LÓPEZ JUAN", "CLAVE DE ELECTOR PRLPJN90010109H100",
                             "CURP PELJ900101HDFRPN09"], photo: true),
                card(color: UIColor(red: 0.93, green: 0.88, blue: 0.95, alpha: 1),
                     lines: ["", "", "", "IDMEX1234567890<<1234567890123",
                             "9001010H3012311MEX<02<<12345<9", "PEREZ<LOPEZ<<JUAN<<<<<<<<<<<<<"],
                     photo: false, monospaced: true),
            ]),
            Sample(title: "Pasaporte", folder: "Identificaciones", pages: [
                card(color: UIColor(red: 0.88, green: 0.93, blue: 0.90, alpha: 1),
                     lines: ["ESTADOS UNIDOS MEXICANOS", "PASAPORTE", "PÉREZ LÓPEZ JUAN",
                             "",
                             "P<MEXPEREZ<LOPEZ<<JUAN<<<<<<<<<<<<<<<<<<<<<<",
                             "G123456780MEX9001012M3001014<<<<<<<<<<<<<<04"],
                     photo: true, monospacedFrom: 4),
            ]),
            Sample(title: "Licencia de conducir", folder: "Identificaciones", pages: [
                card(color: UIColor(red: 0.87, green: 0.91, blue: 0.97, alpha: 1),
                     lines: ["GOBIERNO DEL ESTADO", "LICENCIA PARA CONDUCIR", "TIPO A",
                             "PÉREZ LÓPEZ JUAN", "VIGENCIA 2030"], photo: true),
            ]),
            Sample(title: "Recibo del agua octubre", folder: "Casa", pages: [letter(
                heading: "SISTEMA DE AGUA POTABLE MUNICIPAL",
                lines: ["Usuario: Juan Pérez López", "Domicilio: Calle Ejemplo 123, Col. Centro",
                        "", "PERIODO FACTURADO 01 SEP - 31 OCT", "Consumo: 18 m³",
                        "", "TOTAL A PAGAR $286.00", "FECHA LIMITE DE PAGO 15 NOV"],
                signers: [])]),
            Sample(title: "Recibo de nómina septiembre", folder: "Trabajo", pages: [letter(
                heading: "RECIBO DE NÓMINA",
                lines: ["Empresa Ejemplo S.A. de C.V.", "Empleado: Juan Pérez López", "",
                        "PERCEPCIONES 24,000.00", "DEDUCCIONES 3,850.00", "NETO A PAGAR 20,150.00"],
                signers: [])]),
            Sample(title: "Factura laptop", folder: "Trabajo", pages: [letter(
                heading: "FACTURA",
                lines: ["Tienda Ejemplo S.A. de C.V.", "FOLIO FISCAL 12345678-ABCD-1234-ABCD-123456789012",
                        "", "1 Laptop 14 pulgadas      $18,999.00", "IVA                       $3,039.84",
                        "TOTAL                     $22,038.84", "", "SELLO DIGITAL DEL CFDI"],
                signers: [])]),
        ]
    }

    private static var englishSamples: [Sample] {
        [
            Sample(title: "Lease agreement", folder: "Home", pages: [letter(
                heading: "RESIDENTIAL LEASE AGREEMENT",
                lines: ["This agreement is made between Jane Roe (the Landlord)",
                        "and John Doe (the Tenant).",
                        "",
                        "1. Premises. The Landlord rents to the Tenant the apartment at",
                        "123 Sample Street, Springfield, for a term of twelve months.",
                        "2. Rent. The monthly rent is $1,450.00, due on the first day",
                        "of each month.",
                        "3. Deposit. The Tenant pays a security deposit of one month's rent.",
                        "4. Utilities. Water, electricity and internet are paid",
                        "by the Tenant."],
                signers: ["LANDLORD", "TENANT"])]),
            Sample(title: "Driver license", folder: "IDs", pages: [
                card(color: UIColor(red: 0.87, green: 0.91, blue: 0.97, alpha: 1),
                     lines: ["SAMPLE STATE", "DRIVER LICENSE", "DL 12345678 CLASS C",
                             "DOE, JOHN", "DOB 01/01/1990", "EXP 01/01/2030"], photo: true),
            ]),
            Sample(title: "Passport", folder: "IDs", pages: [
                card(color: UIColor(red: 0.88, green: 0.91, blue: 0.96, alpha: 1),
                     lines: ["UNITED STATES OF AMERICA", "PASSPORT", "DOE, JOHN",
                             "",
                             "P<USADOE<<JOHN<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<",
                             "1234567890USA9001012M3001014<<<<<<<<<<<<<<04"],
                     photo: true, monospacedFrom: 4),
            ]),
            Sample(title: "Social Security card", folder: "IDs", pages: [
                card(color: UIColor(red: 0.93, green: 0.95, blue: 0.97, alpha: 1),
                     lines: ["SOCIAL SECURITY", "123-45-6789", "THIS NUMBER HAS BEEN ESTABLISHED FOR",
                             "JOHN DOE"], photo: false),
            ]),
            Sample(title: "Electric bill October", folder: "Home", pages: [letter(
                heading: "Sample City Electric",
                lines: ["Account Number 1234567890-1", "Service Address 123 Sample Street, Springfield",
                        "", "Billing Period Sep 1 - Oct 31", "Electric usage: 512 kWh",
                        "", "Amount Due $84.20", "Payment Due Nov 15"],
                signers: [])]),
            Sample(title: "Pay stub September", folder: "Work", pages: [letter(
                heading: "EARNINGS STATEMENT",
                lines: ["Sample Company Inc.", "Employee: John Doe", "",
                        "Gross Pay 4,200.00", "Taxes 760.00", "Net Pay 3,440.00"],
                signers: [])]),
            Sample(title: "W-2 2025", folder: "Work", pages: [letter(
                heading: "Form W-2 Wage and Tax Statement 2025",
                lines: ["a Employee's social security number 123-45-6789", "",
                        "1 Wages, tips, other compensation 50,400.00",
                        "2 Federal income tax withheld 6,120.00",
                        "3 Social security wages 50,400.00"],
                signers: [])]),
        ]
    }

    // MARK: - Drawing

    /// A letter-size page with a heading, body text and optional signature lines.
    private static func letter(heading: String, lines: [String], signers: [String]) -> UIImage {
        let size = CGSize(width: 1275, height: 1650)
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            draw(heading, at: CGPoint(x: 110, y: 130), font: .systemFont(ofSize: 40, weight: .bold))
            var y: CGFloat = 230
            for line in lines {
                draw(line, at: CGPoint(x: 110, y: y), font: .systemFont(ofSize: 28))
                y += 46
            }
            guard !signers.isEmpty else { return }
            let baseline: CGFloat = 1380
            for (index, signer) in signers.enumerated() {
                let x = 140 + CGFloat(index) * 540
                UIColor.darkGray.setStroke()
                let rule = UIBezierPath()
                rule.move(to: CGPoint(x: x, y: baseline))
                rule.addLine(to: CGPoint(x: x + 420, y: baseline))
                rule.lineWidth = 2
                rule.stroke()
                draw(signer, at: CGPoint(x: x + 110, y: baseline + 16), font: .systemFont(ofSize: 24, weight: .semibold))
                signature(in: CGRect(x: x + 40, y: baseline - 130, width: 340, height: 120), variant: index)
            }
        }
    }

    /// An ID-sized card, as the scanner crops it.
    private static func card(color: UIColor, lines: [String], photo: Bool,
                             monospaced: Bool = false, monospacedFrom: Int? = nil) -> UIImage {
        let size = CGSize(width: 1012, height: 638)
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            color.setFill()
            UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 36).fill()
            var x: CGFloat = 50
            if photo {
                let frame = CGRect(x: 50, y: 150, width: 230, height: 290)
                UIColor(white: 0.82, alpha: 1).setFill()
                UIBezierPath(roundedRect: frame, cornerRadius: 12).fill()
                let person = UIImage(systemName: "person.fill")?
                    .withTintColor(UIColor(white: 0.6, alpha: 1), renderingMode: .alwaysOriginal)
                person?.draw(in: frame.insetBy(dx: 30, dy: 50))
                x = 320
            }
            var y: CGFloat = 50
            for (index, line) in lines.enumerated() {
                let mono = monospaced || (monospacedFrom.map { index >= $0 } ?? false)
                let font: UIFont = mono ? .monospacedSystemFont(ofSize: 30, weight: .medium)
                    : index == 0 ? .systemFont(ofSize: 36, weight: .heavy)
                    : .systemFont(ofSize: 30, weight: .semibold)
                draw(line, at: CGPoint(x: mono ? 50 : (index == 0 ? 50 : x), y: index == 0 ? y : y + 50), font: font)
                y += mono ? 56 : 62
            }
        }
    }

    private static func signature(in rect: CGRect, variant: Int) {
        let path = UIBezierPath()
        let points: [(CGFloat, CGFloat)] = variant == 0
            ? [(0, 0.7), (0.12, 0.1), (0.2, 0.8), (0.3, 0.3), (0.42, 0.75), (0.55, 0.2), (0.68, 0.7), (0.8, 0.4), (1, 0.6)]
            : [(0, 0.5), (0.1, 0.9), (0.2, 0.15), (0.33, 0.7), (0.45, 0.35), (0.6, 0.85), (0.72, 0.25), (0.86, 0.65), (1, 0.45)]
        path.move(to: CGPoint(x: rect.minX + points[0].0 * rect.width, y: rect.minY + points[0].1 * rect.height))
        for (a, b) in zip(points, points.dropFirst()) {
            let end = CGPoint(x: rect.minX + b.0 * rect.width, y: rect.minY + b.1 * rect.height)
            let control = CGPoint(x: rect.minX + (a.0 + b.0) / 2 * rect.width, y: rect.minY + a.1 * rect.height)
            path.addQuadCurve(to: end, controlPoint: control)
        }
        path.lineWidth = 5
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        UIColor(red: 0.1, green: 0.2, blue: 0.6, alpha: 1).setStroke()
        path.stroke()
    }

    private static func draw(_ text: String, at point: CGPoint, font: UIFont) {
        (text as NSString).draw(at: point, withAttributes: [.font: font, .foregroundColor: UIColor(white: 0.12, alpha: 1)])
    }

    private static var format: UIGraphicsImageRendererFormat {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return format
    }
}
#endif
