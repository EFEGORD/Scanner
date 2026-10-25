import UIKit

extension UIApplication {
    /// The view controller currently on screen, walking up through presented sheets —
    /// used to present the interstitial ad and the iOS share sheet from SwiftUI.
    static func topViewController() -> UIViewController? {
        let root = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController
        var top = root
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}
