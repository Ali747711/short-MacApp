import XCTest
@testable import SmartClipboardAI

final class ClipboardIgnoreRulesTests: XCTestCase {
    func testStoresPlainText() {
        let decision = ClipboardFilter.evaluate(
            rawText: "hello",
            types: ["public.utf8-plain-text"],
            lastStoredText: nil
        )
        XCTAssertEqual(decision, .store(text: "hello", isTruncated: false))
    }

    func testIgnoresNilText() {
        XCTAssertEqual(
            ClipboardFilter.evaluate(rawText: nil, types: [], lastStoredText: nil),
            .ignore
        )
    }

    func testIgnoresWhitespaceOnly() {
        XCTAssertEqual(
            ClipboardFilter.evaluate(rawText: "   \n\t ", types: [], lastStoredText: nil),
            .ignore
        )
    }

    func testIgnoresConcealedType() {
        let decision = ClipboardFilter.evaluate(
            rawText: "s3cret",
            types: [ClipboardFilter.concealedType],
            lastStoredText: nil
        )
        XCTAssertEqual(decision, .ignore)
    }

    func testIgnoresTransientType() {
        let decision = ClipboardFilter.evaluate(
            rawText: "temp",
            types: [ClipboardFilter.transientType],
            lastStoredText: nil
        )
        XCTAssertEqual(decision, .ignore)
    }

    func testIgnoresDuplicateOfLast() {
        let decision = ClipboardFilter.evaluate(
            rawText: "same",
            types: [],
            lastStoredText: "same"
        )
        XCTAssertEqual(decision, .ignore)
    }

    func testTruncatesOverLimitAndFlags() {
        let long = String(repeating: "a", count: ClipboardFilter.maxLength + 500)
        let decision = ClipboardFilter.evaluate(rawText: long, types: [], lastStoredText: nil)
        XCTAssertEqual(
            decision,
            .store(text: String(repeating: "a", count: ClipboardFilter.maxLength), isTruncated: true)
        )
    }

    func testDuplicateComparedAfterTruncation() {
        let long = String(repeating: "b", count: ClipboardFilter.maxLength + 10)
        let truncated = String(repeating: "b", count: ClipboardFilter.maxLength)
        let decision = ClipboardFilter.evaluate(rawText: long, types: [], lastStoredText: truncated)
        XCTAssertEqual(decision, .ignore)
    }
}
