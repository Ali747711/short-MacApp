import Foundation
import Observation

/// In-memory clipboard history backed by a debounced JSON file (PRD §F1, §6).
/// Newest item first; capped at `maxItems` with FIFO eviction of the oldest.
@MainActor
@Observable
final class HistoryStore {
    private(set) var items: [ClipboardItem] = []

    static let maxItems = 100

    private let fileURL: URL
    private let saveDebounce: TimeInterval
    private var saveTask: Task<Void, Never>?

    nonisolated init(fileURL: URL = HistoryStore.defaultFileURL, saveDebounce: TimeInterval = 1.0) {
        self.fileURL = fileURL
        self.saveDebounce = saveDebounce
    }

    func add(_ item: ClipboardItem) {
        items.insert(item, at: 0)
        evictOldestNonFavoritesOverLimit()
        scheduleSave()
    }

    /// Trim the oldest un-pinned items so non-favorites stay within `maxItems`.
    /// Favorites are never evicted (PRD §5 / Favorites spec).
    private func evictOldestNonFavoritesOverLimit() {
        var nonFavoriteCount = items.reduce(0) { $0 + ($1.isFavorite ? 0 : 1) }
        guard nonFavoriteCount > Self.maxItems else { return }
        var index = items.count - 1
        while nonFavoriteCount > Self.maxItems, index >= 0 {
            if !items[index].isFavorite {
                items.remove(at: index)
                nonFavoriteCount -= 1
            }
            index -= 1
        }
    }

    /// Remove un-pinned items only; pinned favorites survive (Favorites spec).
    func clear() {
        items.removeAll { !$0.isFavorite }
        scheduleSave()
    }

    /// Attach (or overwrite) the AI result for a stored item (PRD §F4).
    func setResult(_ result: AIResult, for id: ClipboardItem.ID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].aiResult = result
        scheduleSave()
    }

    /// Toggle the pinned state of an item (Favorites spec).
    func toggleFavorite(for id: ClipboardItem.ID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].isFavorite.toggle()
        scheduleSave()
    }

    /// Load persisted history from disk. A missing or corrupt file yields an empty
    /// history rather than an error (acceptable for MVP).
    func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([ClipboardItem].self, from: data) else {
            return
        }
        items = decoded
    }

    /// Persist immediately, cancelling any pending debounced save.
    func saveNow() {
        saveTask?.cancel()
        write(items)
    }

    private func scheduleSave() {
        saveTask?.cancel()
        let debounce = saveDebounce
        saveTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(debounce))
            guard !Task.isCancelled, let self else { return }
            self.write(self.items)
        }
    }

    private func write(_ items: [ClipboardItem]) {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(items)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // Persistence failure is non-fatal for MVP. Never log clipboard contents.
        }
    }

    nonisolated static var defaultFileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base
            .appendingPathComponent("SmartClipboardAI", isDirectory: true)
            .appendingPathComponent("history.json")
    }
}
