import XCTest
@testable import SmartClipboardAI

@MainActor
final class HistoryStoreTests: XCTestCase {
    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("scai-tests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("history.json")
    }

    func testAddInsertsNewestFirst() {
        let store = HistoryStore(fileURL: tempURL())
        store.add(ClipboardItem(text: "first"))
        store.add(ClipboardItem(text: "second"))
        XCTAssertEqual(store.items.map(\.text), ["second", "first"])
    }

    func testFIFOEvictionKeepsMaxItems() {
        let store = HistoryStore(fileURL: tempURL())
        for i in 0..<(HistoryStore.maxItems + 5) {
            store.add(ClipboardItem(text: "item-\(i)"))
        }
        XCTAssertEqual(store.items.count, HistoryStore.maxItems)
        // Newest first; the five oldest were evicted.
        XCTAssertEqual(store.items.first?.text, "item-\(HistoryStore.maxItems + 4)")
        XCTAssertEqual(store.items.last?.text, "item-5")
    }

    func testPersistenceRoundTrip() {
        let url = tempURL()
        let item = ClipboardItem(text: "persist me", isTruncated: true)

        let store = HistoryStore(fileURL: url)
        store.add(item)
        store.saveNow()

        let reloaded = HistoryStore(fileURL: url)
        reloaded.load()
        XCTAssertEqual(reloaded.items.count, 1)
        XCTAssertEqual(reloaded.items.first, item)
    }

    func testClearPersistsEmpty() {
        let url = tempURL()
        let store = HistoryStore(fileURL: url)
        store.add(ClipboardItem(text: "x"))
        store.saveNow()

        store.clear()
        store.saveNow()

        let reloaded = HistoryStore(fileURL: url)
        reloaded.load()
        XCTAssertTrue(reloaded.items.isEmpty)
    }
}
