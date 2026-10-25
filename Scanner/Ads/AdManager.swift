import Foundation
import GoogleMobileAds
import UIKit

/// Shows the interstitial ad that appears right when the user saves or shares a finished
/// scan (never anywhere else — see Anuncio.dc.html in the design canvas for the UX).
/// The app has no premium tier: this is the only monetization.
final class AdManager: NSObject, GADFullScreenContentDelegate {
    static let shared = AdManager()

    /// Replace with the real AdMob interstitial unit ID before release. This is Google's
    /// public SAMPLE unit ID — safe to ship during development, never serves real ads.
    private let adUnitID = "ca-app-pub-3940256099942544/4411468910"

    private var interstitial: GADInterstitialAd?

    private override init() {
        super.init()
        preload()
    }

    func preload() {
        GADInterstitialAd.load(withAdUnitID: adUnitID, request: GADRequest()) { [weak self] ad, error in
            self?.interstitial = ad
            self?.interstitial?.fullScreenContentDelegate = self
        }
    }

    /// Call right before returning to the Biblioteca after "Guardar" or any share action.
    func showIfReady(from viewController: UIViewController, completion: @escaping () -> Void) {
        guard let interstitial else {
            completion() // no ad ready yet — never block the user's save/share on an ad
            return
        }
        pendingCompletion = completion
        interstitial.present(fromRootViewController: viewController)
    }

    private var pendingCompletion: (() -> Void)?

    func adDidDismissFullScreenContent(_ ad: any GADFullScreenPresentingAd) {
        preload() // get the next one ready
        pendingCompletion?()
        pendingCompletion = nil
    }

    func ad(_ ad: any GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        pendingCompletion?()
        pendingCompletion = nil
    }
}
