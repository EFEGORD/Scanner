import UIKit

/// One page being edited: the untouched source image plus the edits on top. Filters and
/// rotation are re-applied from the source every time, so switching filters never degrades
/// the image.
struct PageEditState: Identifiable {
    let id = UUID()
    let original: UIImage
    private let previewBase: UIImage
    private let initialFilter: PageFilter

    var filter: PageFilter
    var quarterTurns = 0
    var signatures: [PlacedSignature] = []

    init(original: UIImage, filter: PageFilter = .original) {
        self.original = original
        self.previewBase = original.downscaled(maxDimension: 1400)
        self.initialFilter = filter
        self.filter = filter
    }

    var hasEdits: Bool {
        filter != initialFilter || quarterTurns % 4 != 0 || !signatures.isEmpty
    }

    /// Rotated + filtered, at preview size. Signatures are drawn on top by the editor UI.
    func preview() -> UIImage {
        PageRenderer.apply(filter, to: PageRenderer.rotated(previewBase, quarterTurns: quarterTurns))
    }

    /// Full resolution, with signatures baked in — what gets encrypted and saved.
    func rendered() -> UIImage {
        let page = PageRenderer.apply(filter, to: PageRenderer.rotated(original, quarterTurns: quarterTurns))
        return PageRenderer.composite(signatures, onto: page)
    }
}
