import AppKit

/// Polls `NSPasteboard.general.changeCount` every 0.5 s and emits new clipboard
/// items that pass the F1 ignore rules. Owns no UI and no storage (PRD §6).
///
/// Not `@MainActor`-isolated so `deinit` can invalidate the `Timer` freely; the
/// timer is scheduled on the main run loop, so `poll()` always runs on the main
/// thread and hops onto the main actor to deliver items.
final class ClipboardMonitor {
    /// Delivered on the main actor for each captured item.
    var onNewItem: (@MainActor (ClipboardItem) -> Void)?

    private let pasteboard: NSPasteboard
    private let pollInterval: TimeInterval
    private var timer: Timer?
    private var lastChangeCount: Int
    private var lastStoredText: String?

    init(pasteboard: NSPasteboard = .general, pollInterval: TimeInterval = 0.5) {
        self.pasteboard = pasteboard
        self.pollInterval = pollInterval
        self.lastChangeCount = pasteboard.changeCount
    }

    deinit {
        timer?.invalidate()
    }

    func start() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.poll()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// After the app writes its own result to the pasteboard, call this with the
    /// post-write `changeCount` so the resulting change is not captured (PRD §F5).
    func ignoreChange(upTo changeCount: Int) {
        lastChangeCount = changeCount
    }

    private func poll() {
        let currentCount = pasteboard.changeCount
        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount

        let types = pasteboard.types?.map(\.rawValue) ?? []
        let rawText = pasteboard.string(forType: .string)

        guard case let .store(text, isTruncated) = ClipboardFilter.evaluate(
            rawText: rawText,
            types: types,
            lastStoredText: lastStoredText
        ) else { return }

        lastStoredText = text
        let item = ClipboardItem(text: text, isTruncated: isTruncated)

        // Timer runs on the main thread; deliver on the main actor.
        MainActor.assumeIsolated {
            onNewItem?(item)
        }
    }
}
