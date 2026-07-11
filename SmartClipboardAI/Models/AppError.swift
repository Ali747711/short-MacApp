import Foundation

/// The single user-facing error type. Every failure maps to one of the
/// human-readable strings in PRD §F4 — raw response bodies are never surfaced.
enum AppError: Error, Equatable {
    case missingAPIKey
    case invalidAPIKey
    case rateLimited
    case networkError

    var message: String {
        switch self {
        case .missingAPIKey: "Add your Claude API key in Settings"
        case .invalidAPIKey: "Invalid API key"
        case .rateLimited: "Rate limited — try again in a moment"
        case .networkError: "Network error — check your connection"
        }
    }

    /// True when the remedy is to open Settings and add a key.
    var isMissingKey: Bool { self == .missingAPIKey }
}
