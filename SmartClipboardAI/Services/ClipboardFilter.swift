import Foundation

/// Pure decision logic for whether a pasteboard change should become a history
/// entry (PRD §F1). Extracted from `ClipboardMonitor` so the ignore rules are
/// unit-testable without touching the real `NSPasteboard`.
enum ClipboardFilter {
    /// Max characters stored per entry. Longer text is truncated and flagged.
    static let maxLength = 10_000

    /// Pasteboard types marking secret / transient content we must never store.
    static let concealedType = "org.nspasteboard.ConcealedType"
    static let transientType = "org.nspasteboard.TransientType"

    enum Decision: Equatable {
        case ignore
        case store(text: String, isTruncated: Bool)
    }

    /// - Parameters:
    ///   - rawText: the pasteboard's string content (`nil` if none).
    ///   - types: the pasteboard's declared type identifiers.
    ///   - lastStoredText: the text of the most recently stored entry, for de-duping.
    static func evaluate(rawText: String?, types: [String], lastStoredText: String?) -> Decision {
        // Never capture secrets or transient content (password managers mark these).
        if types.contains(concealedType) || types.contains(transientType) {
            return .ignore
        }

        guard let raw = rawText,
              !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .ignore
        }

        let isTruncated = raw.count > maxLength
        let text = isTruncated ? String(raw.prefix(maxLength)) : raw

        // Duplicate of the most recent entry (compared post-truncation).
        if lastStoredText == text {
            return .ignore
        }

        return .store(text: text, isTruncated: isTruncated)
    }
}
