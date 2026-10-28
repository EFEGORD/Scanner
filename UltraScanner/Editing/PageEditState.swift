import UIKit

/// One page being edited: the untouched source image plus the edits on top. Crop, filters and
/// rotation are re-applied from the source every time, so changing them never degrades the image.
struct PageEditState: Identifiable {
    let id = UUID()
    let original: UIImage
    private let previewBase: UIImage
    private let thumbnailBase: UIImage
    private let initialFilter: PageFilter
    private let initialCrop: PageQuad?

    var filter: PageFilter
    var quarterTurns = 0
    var signatures: [PlacedSignature] = []
    /// The document's corners in a photo (found on import, or set in Recortar); nil keeps it whole.
    var crop: PageQuad? {
        didSet { thumbnail = PageRenderer.cropped(thumbnailBase, to: crop) }
    }
    /// Small and cropped, for the page grid in Revisión.
    private(set) var thumbnail: UIImage

    init(original: UIImage, filter: PageFilter = .original, crop: PageQuad? = nil) {
        let previewBase = original.downscaled(maxDimension: 1400)
        let thumbnailBase = previewBase.downscaled(maxDimension: 500)
        self.original = original
        self.previewBase = previewBase
        self.thumbnailBase = thumbnailBase
        self.initialFilter = filter
        self.initialCrop = crop
        self.filter = filter
        self.crop = crop
        self.thumbnail = PageRenderer.cropped(thumbnailBase, to: crop)
    }

    var hasEdits: Bool {
        filter != initialFilter || quarterTurns % 4 != 0 || !signatures.isEmpty || crop != initialCrop
    }

    /// Cropped + rotated + filtered, at preview size. Signatures are drawn on top by the editor UI.
    func preview() -> UIImage {
        PageRenderer.apply(filter, to: PageRenderer.rotated(PageRenderer.cropped(previewBase, to: crop),
                                                            quarterTurns: quarterTurns))
    }

    /// What Recortar shows: the whole page, turned like the preview, without crop or filter.
    func cropSource() -> UIImage {
        PageRenderer.rotated(previewBase, quarterTurns: quarterTurns)
    }

    /// Full resolution, with signatures baked in — what gets encrypted and saved.
    func rendered() -> UIImage {
        let page = PageRenderer.apply(filter, to: PageRenderer.rotated(PageRenderer.cropped(original, to: crop),
                                                                       quarterTurns: quarterTurns))
        return PageRenderer.composite(signatures, onto: page)
    }
}
