import XCTest
import UIKit
import GRDB
import PDFKit
@testable import UltraScanner

// MARK: - Helpers

private func textImage(_ lines: [String]) -> UIImage {
    let size = CGSize(width: 1240, height: 1754)
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    return UIGraphicsImageRenderer(size: size, format: format).image { context in
        UIColor.white.setFill()
        context.fill(CGRect(origin: .zero, size: size))
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 72),
            .foregroundColor: UIColor.black,
        ]
        for (index, line) in lines.enumerated() {
            (line as NSString).draw(at: CGPoint(x: 100, y: 200 + CGFloat(index) * 140), withAttributes: attributes)
        }
    }
}

private func solidImage(_ color: UIColor, size: CGSize) -> UIImage {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    return UIGraphicsImageRenderer(size: size, format: format).image { context in
        color.setFill()
        context.fill(CGRect(origin: .zero, size: size))
    }
}

/// 0 = black, 1 = white.
private func brightness(of image: UIImage, at point: CGPoint) -> CGFloat {
    guard let cgImage = image.cgImage else { return -1 }
    var pixel = [UInt8](repeating: 0, count: 4)
    let context = CGContext(data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                            space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.draw(cgImage, in: CGRect(x: -point.x, y: -(CGFloat(cgImage.height) - point.y - 1),
                                     width: CGFloat(cgImage.width), height: CGFloat(cgImage.height)))
    return (CGFloat(pixel[0]) + CGFloat(pixel[1]) + CGFloat(pixel[2])) / (3 * 255)
}

// MARK: - Cifrado de la base de datos (lo que hace la versión Release)

final class DatabaseEncryptionTests: XCTestCase {
    private var directory: URL!
    private let secret = "CONFIDENCIALXYZ"

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("db-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func insertSampleDocument(into queue: DatabaseQueue) throws {
        try queue.write { db in
            let folder = ScanFolder(name: "Personal")
            try folder.insert(db)
            let document = ScanDocument(title: "Credencial", folderId: folder.id)
            try document.insert(db)
            try ScanPage(documentId: document.id, position: 0, imagePath: "a.jpg", thumbPath: "b.jpg",
                         ocrText: "nombre \(secret) domicilio").insert(db)
        }
    }

    private func fileContainsSecret(_ url: URL) throws -> Bool {
        try Data(contentsOf: url).range(of: Data(secret.utf8)) != nil
    }

    func testPlaintextDatabaseIsMovedToAnEncryptedOne() throws {
        let url = directory.appendingPathComponent("scanner.sqlite")
        // Like the database an earlier version of the app left on the phone.
        let plain = try DatabaseManager.open(url, passphrase: nil)
        try DatabaseManager.migrator.migrate(plain)
        try insertSampleDocument(into: plain)
        try plain.close()
        XCTAssertTrue(try fileContainsSecret(url), "sin cifrar, el texto se lee directo del archivo")

        try DatabaseManager.encryptPlaintextDatabase(at: url, passphrase: "clave-de-prueba")

        XCTAssertFalse(try fileContainsSecret(url))
        XCTAssertThrowsError(try DatabaseManager.open(url, passphrase: nil))
        XCTAssertThrowsError(try DatabaseManager.open(url, passphrase: "otra-clave"))

        let encrypted = try DatabaseManager.open(url, passphrase: "clave-de-prueba")
        try encrypted.read { db in
            XCTAssertEqual(try ScanDocument.fetchCount(db), 1)
            XCTAssertEqual(try ScanPage.fetchCount(db), 1)
            XCTAssertEqual(try ScanFolder.fetchOne(db)?.name, "Personal")
            let hits = try Int.fetchOne(db, sql: """
                SELECT count(*) FROM pages_fts JOIN pages ON pages.rowid = pages_fts.rowid
                WHERE pages_fts MATCH ?
                """, arguments: ["\"confidencial\"*"])
            XCTAssertEqual(hits, 1, "el buscador sigue funcionando después de cifrar")
        }
        try encrypted.close()

        // A second run (file already encrypted) leaves it as it is.
        try DatabaseManager.encryptPlaintextDatabase(at: url, passphrase: "clave-de-prueba")
        XCTAssertNoThrow(try DatabaseManager.open(url, passphrase: "clave-de-prueba").close())
    }

    func testNewEncryptedDatabaseNeverHoldsReadableText() throws {
        let url = directory.appendingPathComponent("nueva.sqlite")
        let queue = try DatabaseManager.open(url, passphrase: "clave-de-prueba")
        try DatabaseManager.migrator.migrate(queue)
        try insertSampleDocument(into: queue)
        try queue.close()

        XCTAssertFalse(try fileContainsSecret(url))
        XCTAssertThrowsError(try DatabaseManager.open(url, passphrase: nil))
    }

    /// Firebase Analytics links the system SQLite too; if it wins the link, nothing is encrypted
    /// (see OTHER_LDFLAGS in project.yml).
    func testSQLiteIsSQLCipher() throws {
        let queue = try DatabaseManager.open(directory.appendingPathComponent("version.sqlite"), passphrase: nil)
        let version = try queue.read { db in try String.fetchOne(db, sql: "PRAGMA cipher_version") }
        XCTAssertNotNil(version, "el SQLite de la app no es SQLCipher")
        try queue.close()
    }

    func testMissingDatabaseIsLeftAlone() throws {
        let url = directory.appendingPathComponent("no-existe.sqlite")
        try DatabaseManager.encryptPlaintextDatabase(at: url, passphrase: "clave-de-prueba")
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }
}

// MARK: - Búsqueda: lo que escribe el usuario → consulta FTS5

final class SearchExpressionTests: XCTestCase {
    func testWordsBecomePrefixTerms() {
        XCTAssertEqual(DocumentRepository.ftsMatchExpression(for: "factura marzo"), "\"factura\"* \"marzo\"*")
    }

    func testPunctuationIsDropped() {
        XCTAssertEqual(DocumentRepository.ftsMatchExpression(for: "luz-octubre"), "\"luz\"* \"octubre\"*")
        XCTAssertEqual(DocumentRepository.ftsMatchExpression(for: "\"INE:\""), "\"INE\"*")
    }

    func testEmptyQueryHasNoExpression() {
        XCTAssertNil(DocumentRepository.ftsMatchExpression(for: "   "))
        XCTAssertNil(DocumentRepository.ftsMatchExpression(for: "-- ::"))
    }
}

// MARK: - Editar: filtros, rotación y firma

final class PageRendererTests: XCTestCase {
    func testRotationSwapsSides() {
        let image = solidImage(.white, size: CGSize(width: 300, height: 400))
        XCTAssertEqual(PageRenderer.rotated(image, quarterTurns: 1).size, CGSize(width: 400, height: 300))
        XCTAssertEqual(PageRenderer.rotated(image, quarterTurns: 2).size, CGSize(width: 300, height: 400))
        XCTAssertEqual(PageRenderer.rotated(image, quarterTurns: 4).size, CGSize(width: 300, height: 400))
    }

    func testFiltersKeepThePageSize() {
        let image = textImage(["FILTROS"])
        for filter in [PageFilter.original, .color, .blackAndWhite, .magic] {
            XCTAssertEqual(PageRenderer.apply(filter, to: image).size, image.size, "\(filter)")
        }
    }

    func testBlackAndWhiteRemovesColor() {
        let red = solidImage(.red, size: CGSize(width: 40, height: 40))
        let result = PageRenderer.apply(.blackAndWhite, to: red)
        guard let cgImage = result.cgImage else { return XCTFail("sin imagen") }
        var pixel = [UInt8](repeating: 0, count: 4)
        let context = CGContext(data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(cgImage, in: CGRect(x: -20, y: -20, width: 40, height: 40))
        XCTAssertLessThan(abs(Int(pixel[0]) - Int(pixel[1])), 8)
        XCTAssertLessThan(abs(Int(pixel[1]) - Int(pixel[2])), 8)
    }

    func testSignatureIsDrawnWhereItWasPlaced() {
        let page = solidImage(.white, size: CGSize(width: 1000, height: 1000))
        let signature = PlacedSignature(image: solidImage(.black, size: CGSize(width: 100, height: 50)),
                                        center: CGPoint(x: 0.7, y: 0.8), widthFraction: 0.2)
        let result = PageRenderer.composite([signature], onto: page)
        XCTAssertLessThan(brightness(of: result, at: CGPoint(x: 700, y: 800)), 0.1)
        XCTAssertGreaterThan(brightness(of: result, at: CGPoint(x: 200, y: 200)), 0.9)
    }

    func testEditStateKnowsWhenSomethingChanged() {
        var state = PageEditState(original: solidImage(.white, size: CGSize(width: 30, height: 40)))
        XCTAssertFalse(state.hasEdits)
        state.quarterTurns = 4
        XCTAssertFalse(state.hasEdits)
        state.filter = .magic
        XCTAssertTrue(state.hasEdits)
    }
}

// MARK: - Documentos: OCR, búsqueda, combinar, dividir, editar y borrar (BD y archivos cifrados reales)

final class DocumentFlowTests: XCTestCase {
    private let repository = DocumentRepository.shared
    private var created: [String] = []

    override func tearDownWithError() throws {
        for id in created {
            try? repository.deleteDocument(id: id)
        }
    }

    private func makeDocument(_ title: String, pages lines: [[String]]) async throws -> ScanDocument {
        var pages: [ScanPage] = []
        for (position, pageLines) in lines.enumerated() {
            pages.append(try await PageFactory.makePage(from: textImage(pageLines), position: position))
        }
        let document = try repository.createDocument(title: title, folderId: nil, pages: pages)
        created.append(document.id)
        return document
    }

    func testSearchCombineSplitAndDelete() async throws {
        let bill = try await makeDocument("Prueba factura", pages: [["FACTURA DE LUZ", "OCTUBRE"]])
        let lease = try await makeDocument("Prueba contrato", pages: [["CONTRATO", "ARRENDAMIENTO"], ["FIRMA DEL", "INQUILINO"]])

        let billPages = try repository.pages(of: bill.id)
        let leasePages = try repository.pages(of: lease.id)
        XCTAssertTrue(billPages[0].ocrText?.localizedCaseInsensitiveContains("factura") ?? false,
                      "OCR: \(billPages[0].ocrText ?? "nil")")

        // Búsqueda: palabra completa, a medias, minúsculas y con puntuación.
        XCTAssertTrue(try repository.search("factura").contains { $0.document.id == bill.id })
        XCTAssertTrue(try repository.search("arrend").contains { $0.document.id == lease.id })
        XCTAssertTrue(try repository.search("luz-octubre").contains { $0.document.id == bill.id })
        XCTAssertFalse(try repository.search("factura inquilino").contains { $0.document.id == bill.id })

        // Combinar: la factura + la 2a página del contrato, sin tocar los originales.
        let combined = try repository.createDocument(title: "Combinado", folderId: nil, pages: [
            try PageFactory.duplicate(billPages[0], position: 0),
            try PageFactory.duplicate(leasePages[1], position: 1),
        ])
        created.append(combined.id)
        let combinedPages = try repository.pages(of: combined.id)
        XCTAssertEqual(combinedPages.count, 2)
        XCTAssertEqual(try repository.pages(of: bill.id).count, 1)
        XCTAssertEqual(try repository.pages(of: lease.id).count, 2)
        XCTAssertNotEqual(combinedPages[0].imagePath, billPages[0].imagePath)
        XCTAssertEqual(try SecureFileStore.shared.read(relativePath: combinedPages[0].imagePath),
                       try SecureFileStore.shared.read(relativePath: billPages[0].imagePath))
        XCTAssertTrue(try repository.search("inquilino").contains { $0.document.id == combined.id })

        // Dividir el combinado después de su primera página.
        let secondPart = try repository.splitDocument(combined.id, afterPosition: combinedPages[0].position,
                                                      newTitle: "Parte 2")
        created.append(secondPart.id)
        XCTAssertEqual(try repository.pages(of: combined.id).count, 1)
        XCTAssertEqual(try repository.pages(of: secondPart.id).count, 1)

        // Borrar elimina sus archivos cifrados, pero no los del original.
        let removedPath = try repository.pages(of: secondPart.id)[0].imagePath
        try repository.deleteDocument(id: secondPart.id)
        XCTAssertFalse(SecureFileStore.shared.exists(relativePath: removedPath))
        XCTAssertTrue(SecureFileStore.shared.exists(relativePath: leasePages[1].imagePath))
        XCTAssertNil(try repository.document(id: secondPart.id))
    }

    func testEditingASavedPageReplacesItsImage() async throws {
        let document = try await makeDocument("Prueba edición", pages: [["RECIBO", "SUPERMERCADO"]])
        let page = try repository.pages(of: document.id)[0]
        let original = try XCTUnwrap(UIImage(data: SecureFileStore.shared.read(relativePath: page.imagePath)))

        var state = PageEditState(original: original)
        state.filter = .blackAndWhite
        state.quarterTurns = 1
        let final = state.rendered()
        XCTAssertEqual(final.size.width, original.size.height)

        let fresh = try await PageFactory.makePage(from: final, position: page.position)
        try repository.replacePageImage(page, with: fresh, filter: state.filter, rotation: 90)

        let updated = try repository.pages(of: document.id)[0]
        XCTAssertEqual(updated.imagePath, fresh.imagePath)
        XCTAssertEqual(updated.filter, .blackAndWhite)
        XCTAssertFalse(SecureFileStore.shared.exists(relativePath: page.imagePath))
        XCTAssertEqual(try repository.document(id: document.id)?.thumbnailPath, fresh.thumbPath)
        XCTAssertTrue(try repository.search("supermercado").contains { $0.document.id == document.id })
    }

    func testSavedSignatureKeepsOnlyOne() throws {
        let first = solidImage(.black, size: CGSize(width: 60, height: 20))
        SignatureStore.save(first)
        let firstPath = try XCTUnwrap(repository.savedSignature()?.imagePath)
        SignatureStore.save(solidImage(.blue, size: CGSize(width: 60, height: 20)))
        XCTAssertNotEqual(try repository.savedSignature()?.imagePath, firstPath)
        XCTAssertFalse(SecureFileStore.shared.exists(relativePath: firstPath))
        XCTAssertNotNil(SignatureStore.loadSaved())

        SignatureStore.deleteSaved()
        XCTAssertNil(try repository.savedSignature())
    }
}

// MARK: - PDF al compartir: capa de texto invisible

final class PDFExportTests: XCTestCase {
    /// Darkest pixel of the page as rendered (1 = all white).
    private func darkest(_ page: PDFPage) -> CGFloat {
        let image = page.thumbnail(of: CGSize(width: 306, height: 396), for: .mediaBox)
        guard let cgImage = image.cgImage else { return -1 }
        let width = cgImage.width, height = cgImage.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let context = CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        var darkest: CGFloat = 1
        for i in stride(from: 0, to: pixels.count, by: 4) {
            darkest = min(darkest, (CGFloat(pixels[i]) + CGFloat(pixels[i + 1]) + CGFloat(pixels[i + 2])) / (3 * 255))
        }
        return darkest
    }

    /// The bug this replaces: the OCR text went in as a "free text" annotation that many viewers
    /// drew in a corner of the page.
    func testTextLayerIsSearchableButNeverShows() throws {
        let blank = solidImage(.white, size: CGSize(width: 1240, height: 1754))
        let lines = [TextRecognizer.RecognizedLine(text: "TEXTO INVISIBLE", box: CGRect(x: 0.1, y: 0.8, width: 0.6, height: 0.05)),
                     TextRecognizer.RecognizedLine(text: "segunda linea", box: CGRect(x: 0.1, y: 0.1, width: 0.4, height: 0.04))]
        let pdf = try XCTUnwrap(PDFDocument(data: PDFGenerator.makePDF(pages: [(blank, lines)])))
        let page = try XCTUnwrap(pdf.page(at: 0))

        XCTAssertTrue(page.annotations.isEmpty)
        XCTAssertTrue(page.string?.contains("TEXTO INVISIBLE") ?? false)
        XCTAssertTrue(page.string?.contains("segunda linea") ?? false)
        XCTAssertGreaterThan(darkest(page), 0.98, "la capa de texto no debe verse")
        // Letter width, the scan's proportions.
        XCTAssertEqual(page.bounds(for: .mediaBox).width, 612, accuracy: 0.5)
        XCTAssertEqual(page.bounds(for: .mediaBox).height, 612 * 1754 / 1240, accuracy: 0.5)
    }

    func testScannedTextIsFoundInTheSharedPDF() async throws {
        let image = textImage(["CONTRATO DE ARRENDAMIENTO", "RENTA MENSUAL 9500"])
        let lines = try await TextRecognizer.recognizeLines(in: image)
        let data = PDFGenerator.makePDF(pages: [(image, lines), (image, lines)])
        // Left in the simulator's temporary folder to open it in other PDF viewers.
        try data.write(to: FileManager.default.temporaryDirectory.appendingPathComponent("UltraScannerPDFCheck.pdf"))
        let pdf = try XCTUnwrap(PDFDocument(data: data))

        XCTAssertEqual(pdf.pageCount, 2)
        XCTAssertFalse(pdf.findString("ARRENDAMIENTO", withOptions: .caseInsensitive).isEmpty)
        // Each word sits where it is on the page: the first line is in the top part.
        let hit = try XCTUnwrap(pdf.findString("CONTRATO", withOptions: .caseInsensitive).first)
        let page = try XCTUnwrap(hit.pages.first)
        XCTAssertGreaterThan(hit.bounds(for: page).midY, page.bounds(for: .mediaBox).midY)
    }
}
