import XCTest
@testable import UltraScanner

/// The app is written in Spanish (development language); English comes from
/// Localizable.xcstrings and InfoPlist.xcstrings. New strings are checked with
/// scripts/check-strings.sh.
final class LocalizationTests: XCTestCase {
    private func englishBundle() throws -> Bundle {
        let path = try XCTUnwrap(Bundle.main.path(forResource: "en", ofType: "lproj"), "Falta en.lproj")
        return try XCTUnwrap(Bundle(path: path))
    }

    func testEnglishTableIsComplete() throws {
        let url = try XCTUnwrap(try englishBundle().url(forResource: "Localizable", withExtension: "strings"))
        let table = try XCTUnwrap(NSDictionary(contentsOf: url) as? [String: String])
        XCTAssertGreaterThan(table.count, 150)
        XCTAssertTrue(table.values.allSatisfy { !$0.isEmpty })
    }

    func testEnglishStringsResolve() throws {
        let english = try englishBundle()
        XCTAssertEqual(english.localizedString(forKey: "Mis documentos", value: nil, table: nil), "My documents")
        XCTAssertEqual(english.localizedString(forKey: "Pasaporte", value: nil, table: nil), "Passport")

        let format = english.localizedString(forKey: "%lld páginas", value: nil, table: nil)
        XCTAssertEqual(String(format: format, 3), "3 pages")
    }

    func testInfoPlistPermissionsAreTranslated() throws {
        let english = try englishBundle()
        for key in ["NSCameraUsageDescription", "NSFaceIDUsageDescription", "NSUserTrackingUsageDescription"] {
            let spanish = try XCTUnwrap(Bundle.main.object(forInfoDictionaryKey: key) as? String)
            let translated = english.localizedString(forKey: key, value: nil, table: "InfoPlist")
            XCTAssertNotEqual(translated, key)
            XCTAssertNotEqual(translated, spanish)
        }
    }
}
