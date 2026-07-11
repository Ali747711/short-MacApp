import Foundation

/// A single captured clipboard entry. Pure `Codable` value type — no logic (PRD §6).
struct ClipboardItem: Codable, Identifiable, Equatable {
    let id: UUID
    let text: String
    let copiedAt: Date
    let isTruncated: Bool
    var aiResult: AIResult?
    var isFavorite: Bool

    init(
        id: UUID = UUID(),
        text: String,
        copiedAt: Date = Date(),
        isTruncated: Bool = false,
        aiResult: AIResult? = nil,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.text = text
        self.copiedAt = copiedAt
        self.isTruncated = isTruncated
        self.aiResult = aiResult
        self.isFavorite = isFavorite
    }

    private enum CodingKeys: String, CodingKey {
        case id, text, copiedAt, isTruncated, aiResult, isFavorite
    }

    // Custom decode so history.json entries written before `isFavorite` existed
    // decode as `false` rather than failing. Encoding stays synthesized.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        text = try container.decode(String.self, forKey: .text)
        copiedAt = try container.decode(Date.self, forKey: .copiedAt)
        isTruncated = try container.decode(Bool.self, forKey: .isTruncated)
        aiResult = try container.decodeIfPresent(AIResult.self, forKey: .aiResult)
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
    }
}
