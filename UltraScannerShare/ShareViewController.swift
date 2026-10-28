import UIKit
import UniformTypeIdentifiers

/// "Compartir" › UltraScanner (in Fotos, WhatsApp, Mail, Archivos…): copies the shared photos and
/// PDFs to the App Group inbox and opens UltraScanner, which puts them all in one document to crop,
/// sign and save (ImportInbox in the app). Nothing is read or kept here beyond that copy.
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
        guard let inbox = SharedInbox.directory else {
            return show(String(localized: "No se pudo abrir ningún archivo. Comparte fotos o PDFs."))
        }

        // Written under a hidden name, renamed once complete: the app never sees half a share.
        let staging = inbox.appendingPathComponent(".\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true,
                                                 attributes: [.protectionKey: FileProtectionType.complete])
        var count = 0
        for provider in providers where count < Self.maxFiles {
            guard let type = Self.supportedType(of: provider) else { continue }
            let destination = staging.appendingPathComponent(String(format: "%03d", count + 1))
                .appendingPathExtension(type.preferredFilenameExtension ?? "img")
            if await Self.copy(provider, type: type, to: destination) { count += 1 }
        }

        let batch = inbox.appendingPathComponent(SharedInbox.batchName(), isDirectory: true)
        guard count > 0, (try? FileManager.default.moveItem(at: staging, to: batch)) != nil else {
            try? FileManager.default.removeItem(at: staging)
            return show(String(localized: "No se pudo abrir ningún archivo. Comparte fotos o PDFs."))
        }
        openApp()
    }

    private static func supportedType(of provider: NSItemProvider) -> UTType? {
        provider.registeredTypeIdentifiers.compactMap(UTType.init).first { $0.conforms(to: .pdf) || $0.conforms(to: .image) }
    }

    private static func copy(_ provider: NSItemProvider, type: UTType, to destination: URL) async -> Bool {
        await withCheckedContinuation { continuation in
            _ = provider.loadFileRepresentation(forTypeIdentifier: type.identifier) { url, _ in
                if let url, (try? FileManager.default.copyItem(at: url, to: destination)) != nil {
                    continuation.resume(returning: true)
                    return
                }
                // Some apps hand over the image itself, not a file.
                _ = provider.loadDataRepresentation(forTypeIdentifier: type.identifier) { data, _ in
                    continuation.resume(returning: (try? data?.write(to: destination, options: .completeFileProtection)) != nil)
                }
            }
        }
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
