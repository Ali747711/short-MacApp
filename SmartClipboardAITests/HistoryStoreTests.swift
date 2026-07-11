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

    func testFavoriteExemptFromEviction() {
        let store = HistoryStore(fileURL: tempURL())
        let favorite = ClipboardItem(text: "keep-me", isFavorite: true)
        store.add(favorite)
        for i in 0..<(HistoryStore.maxItems + 10) {
            store.add(ClipboardItem(text: "item-\(i)"))
        }
        XCTAssertTrue(store.items.contains { $0.id == favorite.id })
        XCTAssertEqual(store.items.filter { !$0.isFavorite }.count, HistoryStore.maxItems)
    }

    func testToggleFavoritePersists() {
        let url = tempURL()
        let store = HistoryStore(fileURL: url)
        let item = ClipboardItem(text: "x")
        store.add(item)
        store.toggleFavorite(for: item.id)
        store.saveNow()

        let reloaded = HistoryStore(fileURL: url)
        reloaded.load()
        XCTAssertEqual(reloaded.items.first?.isFavorite, true)
    }

    func testClearKeepsFavorites() {
        let store = HistoryStore(fileURL: tempURL())
        let favorite = ClipboardItem(text: "fav", isFavorite: true)
        store.add(favorite)
        store.add(ClipboardItem(text: "temp"))
        store.clear()
        XCTAssertEqual(store.items.map(\.text), ["fav"])
    }
}
