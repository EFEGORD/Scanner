import CoreGraphics

/// The four corners of the document inside a photo, as fractions of the image (origin top-left).
/// Recortar straightens what's inside them into a flat page (PageRenderer.cropped).
struct PageQuad: Equatable {
    var topLeft: CGPoint
    var topRight: CGPoint
    var bottomRight: CGPoint
    var bottomLeft: CGPoint

    static let full = PageQuad(topLeft: CGPoint(x: 0, y: 0), topRight: CGPoint(x: 1, y: 0),
                               bottomRight: CGPoint(x: 1, y: 1), bottomLeft: CGPoint(x: 0, y: 1))

    /// Clockwise from the top-left, for drawing and dragging.
    var corners: [CGPoint] {
        get { [topLeft, topRight, bottomRight, bottomLeft] }
        set { (topLeft, topRight, bottomRight, bottomLeft) = (newValue[0], newValue[1], newValue[2], newValue[3]) }
    }

    /// Fraction of the image inside the corners.
    var area: CGFloat {
        let points = corners
        var sum: CGFloat = 0
        for index in points.indices {
            let a = points[index], b = points[(index + 1) % points.count]
            sum += a.x * b.y - b.x * a.y
        }
        return abs(sum) / 2
    }

    /// The same corners on the image turned clockwise `quarterTurns` times (negative turns go
    /// back). Each corner keeps its name, so the crop still straightens the page the same way.
    func rotated(quarterTurns: Int) -> PageQuad {
        let turns = ((quarterTurns % 4) + 4) % 4
        var quad = self
        for _ in 0..<turns {
            quad.corners = quad.corners.map { CGPoint(x: 1 - $0.y, y: $0.x) }
        }
        return quad
    }
}
