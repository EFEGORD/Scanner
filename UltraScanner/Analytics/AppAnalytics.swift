import Foundation
import FirebaseAnalytics
import FirebaseCore
import UserMessagingPlatform

/// Firebase Analytics: which features people use, never what's in their documents. Only events
/// with counts and options travel ("saved 3 pages", "shared as PDF"); titles, recognized text,
/// search words, folder names and images never leave the phone.
///
/// Off unless UltraScanner/GoogleService-Info.plist is in the app. Debug builds only send with
/// -USAnalytics YES (and never in the screenshot demo). Consent follows Google's form, the same
/// one the ads use: where GDPR applies (EEA, UK, Switzerland), Analytics runs with storage denied
/// (consent mode defaults in project.yml) until the user answers it; elsewhere it is granted.
enum AppAnalytics {
    enum Event: String {
        case scanSaved = "scan_saved"               // pages, signed
        case documentEdited = "document_edited"     // pages, signed
        case documentShared = "document_shared"     // format
        case documentsCombined = "documents_combined" // pages, scanned_pages
        case documentSplit = "document_split"
        case documentImported = "document_imported" // pages, source (files | shared)
        case searchUsed = "search_used"
        case folderCreated = "folder_created"
        case onboardingFinished = "onboarding_finished"
        case faceIDLockChanged = "face_id_lock_changed" // enabled
    }

    private typealias Consent = [ConsentType: FirebaseAnalytics.ConsentStatus]

    private(set) static var isRunning = false

    static func start() {
        guard !isRunning, Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else { return }
        #if DEBUG
        guard UserDefaults.standard.bool(forKey: "USAnalytics"), !DemoMode.isActive else { return }
        #endif
        FirebaseApp.configure()
        Analytics.setAnalyticsCollectionEnabled(true)
        isRunning = true
        Task { await updateConsent(refresh: true) }
    }

    static func log(_ event: Event, _ parameters: [String: Any] = [:]) {
        guard isRunning else { return }
        Analytics.logEvent(event.rawValue, parameters: parameters.isEmpty ? nil : parameters)
    }

    /// At launch (refreshing Google's consent information, no form) and after the form is answered.
    ///
    /// Keyed on whether GDPR applies, not on ConsentInformation.consentStatus: that one says
    /// "required" wherever the ads form will be shown (e.g. Mexico or the US states), which would
    /// leave Analytics without storage until the first share even where no consent is needed.
    @MainActor
    static func updateConsent(refresh: Bool = false) async {
        guard isRunning else { return }
        if refresh {
            try? await ConsentInformation.shared.requestConsentInfoUpdate(with: RequestParameters())
        }
        // Written by Google's consent SDK after the update; missing (e.g. offline on the very
        // first launch) → stay denied this session.
        guard let gdprApplies = UserDefaults.standard.object(forKey: "IABTCF_gdprApplies") as? Int else { return }
        if gdprApplies == 1 {
            if let answers = consentFromTCF() { Analytics.setConsent(answers) } // else: not answered yet
        } else {
            Analytics.setConsent(allGranted)
        }
    }

    private static var allGranted: Consent {
        [.analyticsStorage: .granted, .adStorage: .granted, .adUserData: .granted, .adPersonalization: .granted]
    }

    /// GDPR answers saved by Google's form (IAB TCF), mapped the way Google documents for consent
    /// mode: storage ← purpose 1; ad user data ← purposes 1 and 7; ad personalization ← purposes 3
    /// and 4; all only if Google (vendor 755) is allowed. nil while the form hasn't been answered.
    private static func consentFromTCF() -> Consent? {
        let defaults = UserDefaults.standard
        guard let purposes = defaults.string(forKey: "IABTCF_PurposeConsents"), !purposes.isEmpty else { return nil }
        let vendors = defaults.string(forKey: "IABTCF_VendorConsents") ?? ""
        func allowed(_ string: String, _ position: Int) -> Bool {
            let characters = Array(string)
            return characters.count >= position && characters[position - 1] == "1"
        }
        let google = allowed(vendors, 755)
        func status(_ wanted: [Int]) -> FirebaseAnalytics.ConsentStatus {
            google && wanted.allSatisfy { allowed(purposes, $0) } ? .granted : .denied
        }
        return [.analyticsStorage: status([1]), .adStorage: status([1]),
                .adUserData: status([1, 7]), .adPersonalization: status([3, 4])]
    }
}
