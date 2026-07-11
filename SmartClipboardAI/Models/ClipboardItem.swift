import Foundation

/// A single captured clipboard entry. Pure `Codable` value type — no logic (PRD §6).
struct ClipboardItem: Codable, Identifiable, Equatable {
    let id: UUID
    let text: String
    let copiedAt: Date
    let isTruncated: Bool
    var aiResult: AIResult?

    init(
        id: UUID = UUID(),
        text: String,
        copiedAt: Date = Date(),
        isTruncated: Bool = false,
        aiResult: AIResult? = nil
    ) {
        self.id = id
        self.text = text
        self.copiedAt = copiedAt
        self.isTruncated = isTruncated
        self.aiResult = aiResult
    }
}
