import Foundation

/// Recognizes what a page is from its OCR text and the barcodes on it — 100% on-device, no
/// network, no model download. It relies on things these documents always carry, so a page is
/// recognized even when it never says what it is:
///   • back of the INE: the machine-readable zone starting with "IDMEX"
///   • passport data page: the machine-readable zone "P<MEX…", "P<USA…"
///   • back of a US driver license / state ID: the AAMVA PDF417 barcode
/// Barcode contents are only inspected here; they are never stored.
enum DocumentClassifier {
    static func classify(text: String, barcodes: [String] = []) -> [DetectedDocument] {
        let normalized = normalize(text)
        // OCR often splits the machine-readable zone with spaces.
        let compact = normalized.replacingOccurrences(of: " ", with: "")

        func has(_ phrases: String...) -> Bool {
            phrases.contains { normalized.contains($0) }
        }
        func matches(_ pattern: String, _ subject: String) -> Bool {
            subject.range(of: pattern, options: .regularExpression) != nil
        }
        // Machine-readable zones are recognized by how a LINE starts: "P<MEX…" anywhere else
        // could just be a surname ending in P inside another zone ("KEMP<<JUAN").
        let lines = text.uppercased().split(whereSeparator: \.isNewline)
            .map { $0.replacingOccurrences(of: " ", with: "") }
        func lineStarts(_ pattern: String) -> Bool {
            lines.contains { matches("^" + pattern, $0) }
        }

        var found: [DetectedDocument] = []
        func add(_ kind: DocumentKind, _ side: DocumentSide? = nil) {
            let document = DetectedDocument(kind: kind, side: side)
            if !found.contains(document) { found.append(document) }
        }

        // MARK: Identification

        if has("CREDENCIAL PARA VOTAR", "INSTITUTO NACIONAL ELECTORAL", "INSTITUTO FEDERAL ELECTORAL", "CLAVE DE ELECTOR") {
            add(.ine, .front)
        }
        if compact.contains("IDMEX") {
            add(.ine, .back)
        }

        let passportCard = has("PASSPORT CARD")
        if passportCard {
            add(.passportCard)
        }
        if lineStarts("P<[A-Z]{3}") || (!passportCard && has("PASAPORTE", "PASSPORT")) {
            add(.passport)
        }

        if has("PERMANENT RESIDENT") {
            add(.greenCard, .front)
        }
        // Three-line machine-readable zone of US cards (green card, passport card) — on the back.
        if lineStarts("C[1<]USA") {
            add(passportCard ? .passportCard : .usIDCard, .back)
        }

        if has("DRIVER LICENSE", "DRIVERS LICENSE", "DRIVER LICENCE", "OPERATOR LICENSE",
               "LICENCIA DE CONDUCIR", "LICENCIA PARA CONDUCIR", "LICENCIA DE MANEJO") {
            add(.driversLicense, .front)
        } else if has("IDENTIFICATION CARD") && has("DOB", "DATE OF BIRTH", "EXP") {
            add(.stateID, .front)
        }
        // AAMVA barcode on the back of US driver licenses and state IDs: the header names the
        // subfile, "DL" for a license and "ID" for an ID card.
        for payload in barcodes where payload.contains("ANSI ") || payload.contains("AAMVA") {
            let isIDCard = matches("ID[0-9]{8}", payload) && !matches("DL[0-9]{8}", payload)
            add(isIDCard ? .stateID : .driversLicense, .back)
        }

        let isW2 = has("WAGE AND TAX STATEMENT")
        // The W-2 also says "social security" and carries an SSN: it must not count as the card.
        if has("SOCIAL SECURITY") && matches("[0-9]{3}[- ]?[0-9]{2}[- ]?[0-9]{4}", normalized) && !isW2 && !has("FORM ") {
            add(.socialSecurityCard)
        }

        if has("CLAVE UNICA DE REGISTRO DE POBLACION") {
            add(.curp)
        }

        // MARK: Taxes

        if has("CONSTANCIA DE SITUACION FISCAL", "CEDULA DE IDENTIFICACION FISCAL") {
            add(.rfcCertificate)
        }
        if has("FOLIO FISCAL", "SELLO DIGITAL DEL CFDI", "COMPROBANTE FISCAL DIGITAL") {
            add(.cfdiInvoice)
        } else if has("INVOICE") && has("INVOICE NUMBER", "INVOICE #", "INVOICE NO", "BILL TO") {
            add(.invoice)
        }
        if isW2 {
            add(.w2)
        }
        if has("REQUEST FOR TAXPAYER IDENTIFICATION NUMBER") || matches("FORM ?W-?9", normalized) {
            add(.w9)
        }
        if has("FORM 1099") || matches("1099-?(NEC|MISC|INT|DIV|K|G|R|B)", compact) {
            add(.form1099)
        }
        if has("INDIVIDUAL INCOME TAX RETURN", "FORM 1040") {
            add(.form1040)
        }

        // MARK: Income

        if has("EARNINGS STATEMENT", "PAY STUB", "PAYSTUB", "RECIBO DE NOMINA", "COMPROBANTE DE NOMINA")
            || (has("NET PAY") && has("GROSS PAY"))
            || (has("PERCEPCIONES") && has("DEDUCCIONES")) {
            add(.payStub)
        }

        // MARK: Other common documents

        if has("ACTA DE NACIMIENTO", "CERTIFICATE OF LIVE BIRTH", "CERTIFICATE OF BIRTH", "BIRTH CERTIFICATE") {
            add(.birthCertificate)
        }

        let mexicanProvider = has("COMISION FEDERAL DE ELECTRICIDAD", "CFE SUMINISTRADOR", "TELMEX", "TELEFONOS DE MEXICO",
                                  "TOTALPLAY", "IZZI", "MEGACABLE", "NATURGY", "AGUA POTABLE", "SISTEMA DE AGUAS", "PREDIAL")
        let mexicanBill = has("TOTAL A PAGAR", "PAGAR ANTES", "FECHA LIMITE DE PAGO", "PERIODO FACTURADO")
        let usService = has("KWH", "ELECTRIC", "NATURAL GAS", "WATER", "SEWER", "ENERGY", "INTERNET", "WIRELESS",
                            "XFINITY", "COMCAST", "SPECTRUM", "VERIZON", "AT&T", "PG&E", "CON EDISON", "DUKE ENERGY")
        let usBill = has("AMOUNT DUE", "PAYMENT DUE", "TOTAL DUE")
            && has("SERVICE ADDRESS", "ACCOUNT NUMBER", "SERVICE PERIOD", "BILLING PERIOD")
        if (mexicanProvider && mexicanBill) || (usService && usBill) {
            add(.utilityBill)
        }

        if (has("ESTADO DE CUENTA") && has("CLABE", "SALDO ANTERIOR", "SALDO FINAL", "SALDO PROMEDIO"))
            || has("BEGINNING BALANCE", "ENDING BALANCE")
            || (has("STATEMENT PERIOD") && has("BALANCE")) {
            add(.bankStatement)
        }

        if has("CONTRATO DE ARRENDAMIENTO", "LEASE AGREEMENT", "RESIDENTIAL LEASE", "RENTAL AGREEMENT")
            || (has("ARRENDADOR") && has("ARRENDATARIO"))
            || (has("LANDLORD") && has("TENANT")) {
            add(.lease)
        }

        if (has("MEMBER ID", "MEMBER #") && has("RXBIN", "RX BIN", "RXPCN", "GROUP", "COPAY"))
            || (has("POLIZA") && has("ASEGURADO")) {
            add(.insuranceCard)
        }

        if has("TARJETA DE CIRCULACION", "VEHICLE REGISTRATION", "CERTIFICATE OF TITLE", "REGISTRATION CARD") {
            add(.vehicleDocument)
        }

        return found
    }

    // MARK: - Storage

    /// "ine.back,passport"
    static func encode(_ documents: [DetectedDocument]) -> String {
        documents.map { document in
            document.side.map { "\(document.kind.rawValue).\($0.rawValue)" } ?? document.kind.rawValue
        }
        .joined(separator: ",")
    }

    static func decode(_ value: String?) -> [DetectedDocument] {
        guard let value, !value.isEmpty else { return [] }
        return value.split(separator: ",").compactMap { item in
            let parts = item.split(separator: ".")
            guard let kind = DocumentKind(rawValue: String(parts[0])) else { return nil }
            return DetectedDocument(kind: kind, side: parts.count > 1 ? DocumentSide(rawValue: String(parts[1])) : nil)
        }
    }

    /// Words added to the search index so the page is found by its type in Spanish or English.
    static func searchTokens(for documents: [DetectedDocument]) -> String {
        var seen = Set<String>()
        var words: [String] = []
        for document in documents {
            let terms = document.kind.searchTerms + document.kind.groupTerms + (document.side?.searchTerms ?? [])
            for term in terms {
                for word in term.lowercased().split(separator: " ") where seen.insert(String(word)).inserted {
                    words.append(String(word))
                }
            }
        }
        return words.joined(separator: " ")
    }

    /// "INE · reverso", "Pasaporte", "INE · frente, INE · reverso" — nil when nothing was recognized.
    static func label(for documents: [DetectedDocument]) -> String? {
        guard !documents.isEmpty else { return nil }
        return documents.map { document in
            document.side.map { "\(document.kind.displayName) · \($0.displayName)" } ?? document.kind.displayName
        }
        .joined(separator: ", ")
    }

    /// Upper case, no accents, no apostrophes ("DRIVER'S" → "DRIVERS"), single spaces.
    static func normalize(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .uppercased()
            .replacingOccurrences(of: "’", with: "")
            .replacingOccurrences(of: "'", with: "")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }
}
