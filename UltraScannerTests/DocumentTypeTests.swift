import XCTest
import GRDB
@testable import UltraScanner

/// Fictitious samples — no real names, numbers or documents.
private enum Samples {
    static let ineFront = """
    INSTITUTO NACIONAL ELECTORAL
    MÉXICO
    CREDENCIAL PARA VOTAR
    NOMBRE PEREZ LOPEZ JUAN
    CLAVE DE ELECTOR PRLPJN90010109H100
    CURP PELJ900101HDFRPN09
    """
    static let ineBack = """
    IDMEX1234567890<<1234567890123
    9001010H3012311MEX<02<<12345<9
    KEMP<LOPEZ<<JUAN<<<<<<<<<<<<<<
    """
    static let mexicanPassport = """
    ESTADOS UNIDOS MEXICANOS
    P<MEXLOPEZ<GARCIA<<MARIA<<<<<<<<<<<<<<<<<<<<
    G123456780MEX9001012F3001014<<<<<<<<<<<<<<04
    """
    static let usPassport = """
    UNITED STATES OF AMERICA
    P<USAMOUSE<<MICKEY<<<<<<<<<<<<<<<<<<<<<<<<<<
    """
    static let texasLicense = """
    TEXAS
    DRIVER LICENSE
    DL 12345678 CLASS C
    DOB 01/01/1990
    EXP 01/01/2030
    """
    static let licenseBarcode = "@\n\u{1e}\rANSI 636015090102DL00410278ZT03190007DLDAQ12345678\nDCSDOE\nDACJOHN\n"
    static let stateIDBarcode = "@\n\u{1e}\rANSI 636015090102ID00410260ZT03010007IDDAQ12345678\nDCSDOE\n"
    static let mexicanLicense = """
    GOBIERNO DE LA CIUDAD DE MÉXICO
    LICENCIA PARA CONDUCIR
    TIPO A
    """
    static let greenCardFront = """
    UNITED STATES OF AMERICA
    PERMANENT RESIDENT
    SURNAME DOE
    """
    static let greenCardBack = """
    C1USA0000000001SRC0000000000<<
    9001011M3001011MEX<<<<<<<<<<<6
    DOE<<JOHN<<<<<<<<<<<<<<<<<<<<<
    """
    static let ssnCard = """
    SOCIAL SECURITY
    123-45-6789
    THIS NUMBER HAS BEEN ESTABLISHED FOR
    JOHN DOE
    """
    static let w2 = """
    Form W-2 Wage and Tax Statement 2025
    a Employee's social security number 123-45-6789
    3 Social security wages 50,000.00
    """
    static let cfeBill = """
    CFE Suministrador de Servicios Básicos
    COMISIÓN FEDERAL DE ELECTRICIDAD
    TOTAL A PAGAR $512.00
    PERIODO FACTURADO 01 SEP 25 - 31 OCT 25
    """
    static let telmexBill = """
    TELMEX
    ESTADO DE CUENTA
    TOTAL A PAGAR $389.00
    FECHA LIMITE DE PAGO 15 NOV 2025
    """
    static let pgeBill = """
    PG&E Energy Statement
    Service Address 123 Main St, San Jose CA
    Account Number 1234567890-1
    Amount Due $84.20
    """
    static let mexicanBankStatement = """
    BBVA
    ESTADO DE CUENTA
    SALDO ANTERIOR 10,000.00
    CLABE 012180001234567891
    """
    static let usBankStatement = """
    Chase Total Checking
    Beginning Balance $1,000.00
    Ending Balance $900.00
    """
    static let payStub = """
    Earnings Statement
    Gross Pay 2,000.00
    Net Pay 1,500.00
    """
    static let mexicanPayStub = """
    RECIBO DE NÓMINA
    PERCEPCIONES 15,000.00
    DEDUCCIONES 2,000.00
    """
    static let lease = """
    RESIDENTIAL LEASE AGREEMENT
    Landlord: Jane Roe
    Tenant: John Doe
    """
    static let insuranceCard = """
    Blue Cross
    Member ID XYZ123456
    Group 12345
    RxBIN 610014
    """
    static let cfdi = """
    FACTURA
    FOLIO FISCAL 12345678-ABCD-1234-ABCD-123456789012
    SELLO DIGITAL DEL CFDI
    """
    static let form1099 = "Form 1099-NEC Nonemployee Compensation 2025"
    static let form1040 = "Form 1040 U.S. Individual Income Tax Return 2025"
    static let birthCertificate = "STATE OF CALIFORNIA CERTIFICATE OF LIVE BIRTH"
    static let actaNacimiento = "ESTADOS UNIDOS MEXICANOS ACTA DE NACIMIENTO REGISTRO CIVIL"
    static let groceryList = "Lista del súper: leche, huevos, pan"
}

final class DocumentClassifierTests: XCTestCase {
    private func classify(_ text: String, barcodes: [String] = []) -> [DetectedDocument] {
        DocumentClassifier.classify(text: text, barcodes: barcodes)
    }

    private func kinds(_ text: String, barcodes: [String] = []) -> Set<DocumentKind> {
        Set(classify(text, barcodes: barcodes).map(\.kind))
    }

    func testINEFrontAndBack() {
        XCTAssertEqual(classify(Samples.ineFront), [DetectedDocument(kind: .ine, side: .front)])
        // The back never says "INE": it is recognized by its IDMEX zone. The surname ending in P
        // ("KEMP<") must not be mistaken for a passport zone.
        XCTAssertEqual(classify(Samples.ineBack), [DetectedDocument(kind: .ine, side: .back)])
        // Both sides photocopied on one sheet.
        XCTAssertEqual(Set(classify(Samples.ineFront + "\n" + Samples.ineBack)),
                       [DetectedDocument(kind: .ine, side: .front), DetectedDocument(kind: .ine, side: .back)])
    }

    func testPassportsByTheirZoneEvenWithoutTheWord() {
        XCTAssertEqual(kinds(Samples.mexicanPassport), [.passport])
        XCTAssertEqual(kinds(Samples.usPassport), [.passport])
    }

    func testDriverLicensesFromBothCountriesAreEquivalent() {
        XCTAssertEqual(classify(Samples.texasLicense), [DetectedDocument(kind: .driversLicense, side: .front)])
        XCTAssertEqual(classify(Samples.mexicanLicense), [DetectedDocument(kind: .driversLicense, side: .front)])
        // Back of a US license: no text, only the AAMVA barcode.
        XCTAssertEqual(classify("", barcodes: [Samples.licenseBarcode]),
                       [DetectedDocument(kind: .driversLicense, side: .back)])
        XCTAssertEqual(classify("", barcodes: [Samples.stateIDBarcode]),
                       [DetectedDocument(kind: .stateID, side: .back)])
    }

    func testOtherUSIdentification() {
        XCTAssertEqual(classify(Samples.greenCardFront), [DetectedDocument(kind: .greenCard, side: .front)])
        XCTAssertEqual(classify(Samples.greenCardBack), [DetectedDocument(kind: .usIDCard, side: .back)])
        XCTAssertEqual(kinds(Samples.ssnCard), [.socialSecurityCard])
    }

    func testW2IsNotMistakenForTheSocialSecurityCard() {
        XCTAssertEqual(kinds(Samples.w2), [.w2])
    }

    func testProofOfAddressInBothCountries() {
        XCTAssertEqual(kinds(Samples.cfeBill), [.utilityBill])
        XCTAssertEqual(kinds(Samples.pgeBill), [.utilityBill])
        // Telmex calls its bill "estado de cuenta": still a utility bill, not a bank statement.
        XCTAssertEqual(kinds(Samples.telmexBill), [.utilityBill])
    }

    func testFinancialAndOtherDocuments() {
        XCTAssertEqual(kinds(Samples.mexicanBankStatement), [.bankStatement])
        XCTAssertEqual(kinds(Samples.usBankStatement), [.bankStatement])
        XCTAssertEqual(kinds(Samples.payStub), [.payStub])
        XCTAssertEqual(kinds(Samples.mexicanPayStub), [.payStub])
        XCTAssertEqual(kinds(Samples.lease), [.lease])
        XCTAssertEqual(kinds(Samples.insuranceCard), [.insuranceCard])
        XCTAssertEqual(kinds(Samples.cfdi), [.cfdiInvoice])
        XCTAssertEqual(kinds(Samples.form1099), [.form1099])
        XCTAssertEqual(kinds(Samples.form1040), [.form1040])
        XCTAssertEqual(kinds(Samples.birthCertificate), [.birthCertificate])
        XCTAssertEqual(kinds(Samples.actaNacimiento), [.birthCertificate])
    }

    func testUnrelatedTextIsNotClassified() {
        XCTAssertTrue(classify(Samples.groceryList).isEmpty)
        XCTAssertTrue(classify("").isEmpty)
    }

    func testEncodingAndLabels() {
        let documents = [DetectedDocument(kind: .ine, side: .back), DetectedDocument(kind: .passport)]
        let encoded = DocumentClassifier.encode(documents)
        XCTAssertEqual(encoded, "ine.back,passport")
        XCTAssertEqual(DocumentClassifier.decode(encoded), documents)
        XCTAssertEqual(DocumentClassifier.label(for: documents), "INE · reverso, Pasaporte")
        XCTAssertNil(DocumentClassifier.label(for: []))

        let tokens = DocumentClassifier.searchTokens(for: [DetectedDocument(kind: .ine, side: .back)])
            .split(separator: " ").map(String.init)
        for word in ["ine", "credencial", "reverso", "back", "identificacion", "identification", "id"] {
            XCTAssertTrue(tokens.contains(word), word)
        }
    }
}

final class DocumentTypeSearchTests: XCTestCase {
    private let repository = DocumentRepository.shared
    private var created: [String] = []

    override func tearDownWithError() throws {
        for id in created {
            try? repository.deleteDocument(id: id)
        }
    }

    private func page(_ text: String, barcodes: [String] = [], position: Int) -> ScanPage {
        let detected = DocumentClassifier.classify(text: text, barcodes: barcodes)
        return ScanPage(documentId: "", position: position,
                        imagePath: "prueba-\(UUID().uuidString).jpg", thumbPath: "prueba-\(UUID().uuidString).jpg",
                        ocrText: text, docTypes: DocumentClassifier.encode(detected),
                        docTags: DocumentClassifier.searchTokens(for: detected))
    }

    func testDocumentsAreFoundByWhatTheyAre() throws {
        let document = try repository.createDocument(title: "Expediente de prueba", folderId: nil, pages: [
            page(Samples.ineFront, position: 0),
            page(Samples.ineBack, position: 1),
            page(Samples.mexicanPassport, position: 2),
            page(Samples.cfeBill, position: 3),
            page("", barcodes: [Samples.licenseBarcode], position: 4),
            page(Samples.pgeBill, position: 5),
        ])
        created.append(document.id)
        let ids = try repository.pages(of: document.id).map(\.id)

        func found(_ query: String) throws -> Set<String> {
            Set(try repository.search(query).filter { $0.document.id == document.id }.map(\.page.id))
        }

        XCTAssertEqual(try found("INE"), [ids[0], ids[1]], "las dos caras, aunque el reverso no diga INE")
        XCTAssertEqual(try found("credencial"), [ids[0], ids[1]])
        XCTAssertEqual(try found("ine reverso"), [ids[1]])
        XCTAssertEqual(try found("pasaporte"), [ids[2]], "la página no dice «pasaporte»")
        XCTAssertEqual(try found("passport"), [ids[2]])
        XCTAssertEqual(try found("identificación"), [ids[0], ids[1], ids[2], ids[4]])
        XCTAssertEqual(try found("comprobante de domicilio"), [ids[3], ids[5]])
        XCTAssertEqual(try found("proof of address"), [ids[3], ids[5]])
        XCTAssertEqual(try found("license"), [ids[4]], "reverso sin texto, solo el código de barras")
        XCTAssertEqual(try repository.pages(of: document.id)[1].documentLabel, "INE · reverso")
    }
}

final class DocumentTypeMigrationTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("mig-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    /// Like the database already on the phone: encrypted, saved before document types existed.
    private func makeVersion1Database(at url: URL, passphrase: String?) throws -> DatabaseQueue {
        let queue = try DatabaseManager.open(url, passphrase: passphrase)
        try DatabaseManager.migrator.migrate(queue, upTo: "v1_initial")
        try queue.write { db in
            try db.execute(sql: """
                INSERT INTO documents (id, title, created_at, updated_at, export_format)
                VALUES ('d1', 'Documento viejo', ?, ?, 'pdf')
                """, arguments: [Date(), Date()])
            try db.execute(sql: """
                INSERT INTO pages (id, document_id, position, image_path, thumb_path, rotation, filter, ocr_text)
                VALUES ('p1', 'd1', 0, 'a.jpg', 'b.jpg', 0, 'color', ?)
                """, arguments: [Samples.ineFront])
        }
        return queue
    }

    private func count(_ queue: DatabaseQueue, _ match: String) throws -> Int {
        try queue.read { db in
            try Int.fetchOne(db, sql: "SELECT count(*) FROM pages_fts WHERE pages_fts MATCH ?", arguments: [match]) ?? 0
        }
    }

    func testEncryptedVersion1DatabaseGetsDocumentTypes() throws {
        let queue = try makeVersion1Database(at: directory.appendingPathComponent("v1.sqlite"), passphrase: "clave")
        try DatabaseManager.migrator.migrate(queue)

        XCTAssertEqual(try count(queue, "\"electoral\"*"), 1, "el texto viejo sigue en el buscador")
        XCTAssertNil(try queue.read { db in try String.fetchOne(db, sql: "SELECT doc_types FROM pages") },
                     "queda pendiente de clasificar en segundo plano")

        let detected = DocumentClassifier.classify(text: Samples.ineFront)
        try queue.write { db in
            try db.execute(sql: "UPDATE pages SET doc_types = ?, doc_tags = ? WHERE id = 'p1'", arguments: [
                DocumentClassifier.encode(detected), DocumentClassifier.searchTokens(for: detected),
            ])
        }
        XCTAssertEqual(try count(queue, "\"identificacion\"*"), 1)
        try queue.close()
    }

    func testOldPlaintextDatabaseIsUpgradedWhileEncrypting() throws {
        let url = directory.appendingPathComponent("scanner.sqlite")
        try makeVersion1Database(at: url, passphrase: nil).close()

        try DatabaseManager.encryptPlaintextDatabase(at: url, passphrase: "clave")

        let encrypted = try DatabaseManager.open(url, passphrase: "clave")
        try encrypted.read { db in
            XCTAssertEqual(try ScanPage.fetchCount(db), 1)
            XCTAssertEqual(try ScanPage.fetchOne(db)?.ocrText, Samples.ineFront)
        }
        XCTAssertEqual(try count(encrypted, "\"electoral\"*"), 1)
        try encrypted.close()
    }
}
