import UIKit
import AppTrackingTransparency
import GoogleMobileAds
import UserMessagingPlatform

/// The only ad in the app: an interstitial right before the share sheet opens. Never while
/// scanning or saving. The app has no premium tier: this is its only monetization.
/// Same approach as UltraVocal's AdsController (AdMob 12 + Google's consent form + ATT).
@MainActor
final class AdManager: NSObject, FullScreenContentDelegate {
    static let shared = AdManager()

    private var interstitial: InterstitialAd?
    private var loadedAt: Date?
    private var loading = false
    private var started = false
    private var consentGatheredThisLaunch = false
    private var pendingShare: (() -> Void)?

    private var unitID: String {
        Bundle.main.object(forInfoDictionaryKey: "USInterstitialAdUnitID") as? String ?? ""
    }

    /// At launch: only if the user already answered the consent form in an earlier session.
    /// Nobody gets asked for consent just for opening the app.
    func prepareIfConsented() {
        guard ConsentInformation.shared.canRequestAds else { return }
        load()
    }

    /// Call when the user taps Compartir. The first time, Google's consent form (where the law
    /// requires it) and Apple's tracking prompt appear first; that share goes ahead without an
    /// ad and one is loaded for the next. A missing ad (no network, no consent) never blocks
    /// sharing.
    func beforeSharing(then share: @escaping () -> Void) {
        Task {
            if !consentGatheredThisLaunch {
                consentGatheredThisLaunch = true
                _ = await gatherConsent()
            }
            guard let ad = interstitial, let root = UIApplication.topViewController() else {
                share()
                load()
                return
            }
            interstitial = nil
            pendingShare = share
            ad.present(from: root)
        }
    }

    private func load() {
        // An interstitial expires after an hour.
        if interstitial != nil, let loadedAt, Date.now.timeIntervalSince(loadedAt) < 50 * 60 { return }
        guard !loading, ConsentInformation.shared.canRequestAds else { return }
        loading = true
        Task {
            defer { loading = false }
            if !started {
                await MobileAds.shared.start()
                started = true
            }
            do {
                let ad = try await InterstitialAd.load(with: unitID, request: Request())
                ad.fullScreenContentDelegate = self
                interstitial = ad
                loadedAt = .now
            } catch {
                interstitial = nil
            }
        }
    }

    func adDidDismissFullScreenContent(_ ad: any FullScreenPresentingAd) {
        continueSharing()
    }

    func ad(_ ad: any FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        continueSharing()
    }

    private func continueSharing() {
        pendingShare?()
        pendingShare = nil
        load()
    }

    /// Google's consent (GDPR and US state laws), then Apple's tracking prompt.
    private func gatherConsent() async -> Bool {
        let info = ConsentInformation.shared
        try? await info.requestConsentInfoUpdate(with: RequestParameters())
        if let root = UIApplication.topViewController() {
            try? await ConsentForm.loadAndPresentIfRequired(from: root)
        }
        if ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
            _ = await ATTrackingManager.requestTrackingAuthorization()
        }
        return info.canRequestAds
    }
}
