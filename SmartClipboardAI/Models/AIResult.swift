import Foundation

/// The AI transformation applied to a clipboard item.
enum AIAction: String, Codable {
    case translate
    case summarize
    case clean
}

/// The stored output of the most recent AI action for a clipboard item (PRD §F1).
struct AIResult: Codable, Equatable {
    let action: AIAction
    let outputText: String
    let createdAt: Date

    init(action: AIAction, outputText: String, createdAt: Date = Date()) {
        self.action = action
        self.outputText = outputText
        self.createdAt = createdAt
    }
}
