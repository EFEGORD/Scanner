import SwiftUI

/// The "Ultra" look: between UltraVocal's lavender (#7A6AC8) and the logo's pink (#FF4F8B).
/// The solid accent (AccentColor in the asset catalog) is the orchid halfway between them,
/// #BC5CA9; the main buttons use the full lavender → pink gradient.
extension ShapeStyle where Self == LinearGradient {
    static var ultraGradient: LinearGradient {
        LinearGradient(colors: [Color(red: 0.478, green: 0.416, blue: 0.784), Color(red: 1, green: 0.310, blue: 0.545)],
                       startPoint: .leading, endPoint: .trailing)
    }
}
