import XCTest
@testable import SmartClipboardAI

final class ClipboardItemTests: XCTestCase {
    func testDecodesMissingIsFavoriteAsFalse() throws {
        let json = """
        {"id":"\(UUID().uuidString)","text":"hi","copiedAt":760000000,"isTruncated":false}
        """
        let item = try JSONDecoder().decode(ClipboardItem.self, from: Data(json.utf8))
        XCTAssertFalse(item.isFavorite)
    }

    func testRoundTripPreservesIsFavorite() throws {
        let item = ClipboardItem(text: "hi", isFavorite: true)
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(ClipboardItem.self, from: data)
        XCTAssertEqual(decoded, item)
        XCTAssertTrue(decoded.isFavorite)
    }
}
