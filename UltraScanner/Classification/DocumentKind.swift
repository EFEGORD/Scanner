import Foundation

/// Document types recognized on-device (Mexico and the US). Search words include synonyms in
/// Spanish and English plus the words of the type's group, so equivalent documents of both
/// countries are found the same way: "identificación" finds an INE, a Texas license or a passport.
enum DocumentKind: String, CaseIterable {
    // Identification
    case ine
    case passport
    case passportCard
    case driversLicense
    case stateID
    case greenCard
    case usIDCard
    case socialSecurityCard
    case curp
    // Taxes
    case rfcCertificate
    case cfdiInvoice
    case invoice
    case w2
    case w9
    case form1099
    case form1040
    // Income, address, other
    case payStub
    case birthCertificate
    case utilityBill
    case bankStatement
    case lease
    case insuranceCard
    case vehicleDocument

    var displayName: String {
        switch self {
        case .ine: return "INE"
        case .passport: return "Pasaporte"
        case .passportCard: return "Passport Card"
        case .driversLicense: return "Licencia de conducir"
        case .stateID: return "Identificación estatal"
        case .greenCard: return "Green card"
        case .usIDCard: return "Identificación de EE. UU."
        case .socialSecurityCard: return "Tarjeta del Seguro Social"
        case .curp: return "CURP"
        case .rfcCertificate: return "Constancia de situación fiscal"
        case .cfdiInvoice: return "Factura (CFDI)"
        case .invoice: return "Factura"
        case .w2: return "W-2"
        case .w9: return "W-9"
        case .form1099: return "1099"
        case .form1040: return "Declaración 1040"
        case .payStub: return "Recibo de nómina"
        case .birthCertificate: return "Acta de nacimiento"
        case .utilityBill: return "Comprobante de domicilio"
        case .bankStatement: return "Estado de cuenta"
        case .lease: return "Contrato de arrendamiento"
        case .insuranceCard: return "Seguro"
        case .vehicleDocument: return "Documento del vehículo"
        }
    }

    /// Own synonyms (Spanish and English).
    var searchTerms: [String] {
        switch self {
        case .ine: return ["ine", "ife", "credencial", "elector", "votar", "credencial para votar", "voter id"]
        case .passport: return ["pasaporte", "passport"]
        case .passportCard: return ["pasaporte", "passport", "passport card"]
        case .driversLicense: return ["licencia", "licencia de conducir", "licencia de manejo", "driver license", "drivers license", "licence", "dl"]
        case .stateID: return ["state id", "identificacion estatal", "id card"]
        case .greenCard: return ["green card", "residencia", "residente", "permanent resident"]
        case .usIDCard: return ["id card", "green card", "passport card"]
        case .socialSecurityCard: return ["seguro social", "social security", "ssn"]
        case .curp: return ["curp"]
        case .rfcCertificate: return ["rfc", "constancia", "situacion fiscal", "cedula fiscal", "tax id"]
        case .cfdiInvoice: return ["factura", "cfdi", "invoice"]
        case .invoice: return ["factura", "invoice"]
        case .w2: return ["w2", "w-2", "wage", "tax statement"]
        case .w9: return ["w9", "w-9", "taxpayer"]
        case .form1099: return ["1099"]
        case .form1040: return ["1040", "declaracion", "tax return"]
        case .payStub: return ["nomina", "recibo de nomina", "pay stub", "paystub", "payslip", "talon de pago", "sueldo", "salary", "earnings"]
        case .birthCertificate: return ["acta", "acta de nacimiento", "nacimiento", "birth certificate", "birth"]
        case .utilityBill: return ["comprobante de domicilio", "comprobante", "domicilio", "proof of address", "address", "recibo", "utility bill", "bill", "luz", "agua", "gas", "telefono", "internet"]
        case .bankStatement: return ["estado de cuenta", "banco", "bank statement", "bank", "statement"]
        case .lease: return ["contrato", "arrendamiento", "renta", "lease", "rental", "rent"]
        case .insuranceCard: return ["seguro", "poliza", "insurance", "seguro medico", "health insurance"]
        case .vehicleDocument: return ["tarjeta de circulacion", "vehiculo", "auto", "coche", "carro", "car", "vehicle", "registration", "title"]
        }
    }

    /// Words shared by every type of the same group — the cross-country equivalences.
    var groupTerms: [String] {
        switch self {
        case .ine, .passport, .passportCard, .driversLicense, .stateID, .greenCard, .usIDCard, .socialSecurityCard, .curp:
            return ["identificacion", "identification", "identidad", "id", "documento de identidad"]
        case .rfcCertificate, .cfdiInvoice, .w2, .w9, .form1099, .form1040:
            return ["impuestos", "fiscal", "taxes", "tax", "sat", "irs"]
        case .payStub:
            return ["ingresos", "income", "comprobante de ingresos", "proof of income"]
        default:
            return []
        }
    }
}

enum DocumentSide: String {
    case front
    case back

    var displayName: String {
        self == .front ? "frente" : "reverso"
    }

    var searchTerms: [String] {
        switch self {
        case .front: return ["frente", "anverso", "delantera", "front"]
        case .back: return ["reverso", "atras", "trasera", "posterior", "vuelta", "back"]
        }
    }
}

struct DetectedDocument: Hashable {
    let kind: DocumentKind
    var side: DocumentSide? = nil
}
