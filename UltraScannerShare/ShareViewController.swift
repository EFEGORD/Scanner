import ImageIO
import UIKit
import UniformTypeIdentifiers

/// "Compartir" › UltraScanner (in Fotos, WhatsApp, Mail, Archivos…): leaves the shared photos and
/// PDFs in the shared Keychain inbox and opens UltraScanner, which puts them all in one document to
/// crop, sign and save (ImportInbox in the app). Nothing is read or kept here beyond that copy.
final class ShareViewController: UIViewController {
    /// The app imports up to 30 pages; more files than that would only be thrown away.
    private static let maxFiles = 30

    private let spinner = UIActivityIndicatorView(style: .large)
    private let message = UILabel()
    private let okButton = UIButton(type: .system)
    private var started = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        message.text = String(localized: "Abriendo en UltraScanner…")
        message.font = .preferredFont(forTextStyle: .headline)
        message.textAlignment = .center
        message.numberOfLines = 0

        okButton.setTitle(String(localized: "OK"), for: .normal)
        okButton.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        okButton.isHidden = true
        okButton.addAction(UIAction { [weak self] _ in self?.close() }, for: .touchUpInside)

        spinner.startAnimating()
        let stack = UIStackView(arrangedSubviews: [spinner, message, okButton])
        stack.axis = .vertical
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor, constant: -12),
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !started else { return }
        started = true
        Task { await receive() }
    }

    private func receive() async {
        let providers = (extensionContext?.inputItems as? [NSExtensionItem] ?? []).flatMap { $0.attachments ?? [] }
        let batch = SharedInbox.batchName()
        var count = 0
        for provider in providers where count < Self.maxFiles {
            guard let type = Self.supportedType(of: provider),
                  let data = await Self.load(provider, type: type),
                  SharedInbox.add(data, batch: batch, file: String(format: "%03d", count + 1)) else { continue }
            count += 1
        }
        // The marker goes last: until it's there the app doesn't touch the batch.
        guard count > 0, SharedInbox.markReady(batch) else {
            for index in 0..<count { SharedInbox.remove(account: "\(batch)/\(String(format: "%03d", index + 1))") }
            return show(String(localized: "No se pudo abrir ningún archivo. Comparte fotos o PDFs."))
        }
        openApp()
    }

    private static func supportedType(of provider: NSItemProvider) -> UTType? {
        provider.registeredTypeIdentifiers.compactMap(UTType.init).first { $0.conforms(to: .pdf) || $0.conforms(to: .image) }
    }

    /// A PDF as it is; a photo upright and at most 3000 px (what the app keeps anyway), as JPEG.
    private static func load(_ provider: NSItemProvider, type: UTType) async -> Data? {
        let data: Data? = await withCheckedContinuation { continuation in
            _ = provider.loadDataRepresentation(forTypeIdentifier: type.identifier) { data, _ in
                continuation.resume(returning: data)
            }
        }
        guard let data else { return nil }
        if type.conforms(to: .pdf) { return data }
        return autoreleasepool { shrunk(data) }
    }

    private static func shrunk(_ data: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                  kCGImageSourceCreateThumbnailFromImageAlways: true,
                  kCGImageSourceCreateThumbnailWithTransform: true,
                  kCGImageSourceThumbnailMaxPixelSize: 3000,
              ] as CFDictionary) else { return nil }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.9] as CFDictionary)
        return CGImageDestinationFinalize(destination) ? output as Data : nil
    }

    /// Extensions can't open their app through a public API (UIApplication.open is off-limits to
    /// them at compile time); the app object in the responder chain still answers it when called
    /// by name. If iOS refuses, the files wait in the inbox and the app imports them the next time
    /// it's opened.
    private func openApp() {
        typealias OpenURL = @convention(c) (AnyObject, Selector, NSURL, NSDictionary,
                                            (@convention(block) (Bool) -> Void)?) -> Void
        let selector = NSSelectorFromString("openURL:options:completionHandler:")
        var responder: UIResponder? = self
        while let current = responder {
            if current is UIApplication, current.responds(to: selector) {
                let open = unsafeBitCast(current.method(for: selector), to: OpenURL.self)
                open(current, selector, SharedInbox.openURL as NSURL, NSDictionary()) { [weak self] opened in
                    DispatchQueue.main.async {
                        if opened {
                            self?.close()
                        } else {
                            self?.show(String(localized: "Listo. Abre UltraScanner para revisarlo y guardarlo."))
                        }
                    }
                }
                return
            }
            responder = current.next
        }
        show(String(localized: "Listo. Abre UltraScanner para revisarlo y guardarlo."))
    }

    private func show(_ text: String) {
        spinner.stopAnimating()
        spinner.isHidden = true
        message.text = text
        okButton.isHidden = false
    }

    private func close() {
        extensionContext?.completeRequest(returningItems: nil)
    }
}
