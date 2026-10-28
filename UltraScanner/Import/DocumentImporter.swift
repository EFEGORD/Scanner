import Foundation
import PDFKit
import UIKit
import UniformTypeIdentifiers

/// Turns photos and files from outside the app (picked in Fotos or Archivos, or shared from another
/// app) into page images for the same review → edit / sign → save flow as a scan. Photos come with
/// the document already found in them (DocumentDetector), ready to crop. Once saved they are
/// encrypted and their text is read like any scan; the outside file itself is never kept.
enum DocumentImporter {
    enum ImportError: LocalizedError {
        case unreadable
        case passwordProtected
        case noPages
        case photosUnavailable

        var errorDescription: String? {
            switch self {
            case .unreadable: String(localized: "No se pudo abrir el archivo.")
            case .passwordProtected: String(localized: "El PDF está protegido con contraseña.")
            case .noPages: String(localized: "El archivo no tiene páginas.")
            case .photosUnavailable: String(localized: "No se pudieron abrir las fotos. Si están en iCloud, revisa tu conexión.")
            }
        }
    }

    enum Source {
        /// A file from Archivos or shared from another app.
        case file(URL)
        /// A photo picked in Fotos.
        case photo(Data)
    }

    struct Page {
        var image: UIImage
        /// Where the document is in a photo; nil for PDF pages and photos without a clear document.
        var crop: PageQuad?
    }

    struct Imported {
        var pages: [Page]
        /// More pages than `maxPages` came in; the rest were left out.
        var truncated: Bool
    }

    static let contentTypes: [UTType] = [.pdf, .image]
    /// Every page stays in memory while it's edited, like a scan.
    static let maxPages = 30
    /// About 200 dpi on a letter page: sharp to read and sign, light enough to edit.
    static let pageWidth: CGFloat = 1700

    static func pages(from urls: [URL]) async throws -> Imported {
        try await pages(from: urls.map(Source.file))
    }

    static func pages(from sources: [Source]) async throws -> Imported {
        try await Task.detached(priority: .userInitiated) {
            var result = Imported(pages: [], truncated: false)
            for source in sources {
                let room = maxPages - result.pages.count
                guard room > 0 else { result.truncated = true; break }
                let file: Imported
                switch source {
                case .file(let url): file = try pages(from: url, limit: room)
                case .photo(let data): file = try photoPage(data)
                }
                result.pages += file.pages
                result.truncated = result.truncated || file.truncated
            }
            guard !result.pages.isEmpty else { throw ImportError.noPages }
            return result
        }.value
    }

    private static func pages(from url: URL, limit: Int) throws -> Imported {
        // Files picked outside the app's container need security-scoped access.
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { throw ImportError.unreadable }

        let type = UTType(filenameExtension: url.pathExtension)
        if type?.conforms(to: .pdf) == true || data.starts(with: Data("%PDF".utf8)) {
            return try pdfPages(data, limit: limit)
        }
        return try photoPage(data)
    }

    private static func photoPage(_ data: Data) throws -> Imported {
        guard let image = UIImage(data: data) else { throw ImportError.unreadable }
        let upright = image.uprighted().downscaled(maxDimension: 3000)
        return Imported(pages: [Page(image: upright, crop: DocumentDetector.detect(in: upright))], truncated: false)
    }

    private static func pdfPages(_ data: Data, limit: Int) throws -> Imported {
        guard let pdf = PDFDocument(data: data) else { throw ImportError.unreadable }
        if pdf.isLocked { throw ImportError.passwordProtected }
        let count = min(pdf.pageCount, limit)
        let pages: [Page] = (0..<count).compactMap { index in
            guard let page = pdf.page(at: index) else { return nil }
            var size = page.bounds(for: .cropBox).size
            if page.rotation % 180 != 0 { size = CGSize(width: size.height, height: size.width) }
            guard size.width > 0, size.height > 0 else { return nil }
            let image = page.thumbnail(of: CGSize(width: pageWidth, height: pageWidth * size.height / size.width), for: .cropBox)
            return Page(image: image, crop: nil)
        }
        return Imported(pages: pages, truncated: pdf.pageCount > limit)
    }
}

private extension UIImage {
    /// Photos often carry their rotation as metadata; the editor and the renderer expect it applied.
    func uprighted() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in draw(in: CGRect(origin: .zero, size: size)) }
    }
}
