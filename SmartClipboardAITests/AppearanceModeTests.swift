import XCTest
@testable import SmartClipboardAI

final class AppearanceModeTests: XCTestCase {
    private func freshDefaults() -> UserDefaults {
        UserDefaults(suiteName: "appearance-tests-\(UUID().uuidString)")!
    }

    func testStoredDefaultsToSystem() {
        XCTAssertEqual(AppearanceMode.stored(in: freshDefaults()), .system)
    }

    func testStoredRoundTrip() {
        let defaults = freshDefaults()
        defaults.set(AppearanceMode.dark.rawValue, forKey: AppearanceMode.defaultsKey)
        XCTAssertEqual(AppearanceMode.stored(in: defaults), .dark)
    }

    func testUnknownRawValueFallsBackToSystem() {
        let defaults = freshDefaults()
        defaults.set("solarized", forKey: AppearanceMode.defaultsKey)
        XCTAssertEqual(AppearanceMode.stored(in: defaults), .system)
    }

    func testAllCasesOrder() {
        XCTAssertEqual(AppearanceMode.allCases, [.system, .light, .dark])
    }
}
