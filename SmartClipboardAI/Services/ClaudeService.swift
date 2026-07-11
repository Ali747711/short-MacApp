import Foundation

/// Supplies the Claude API key. `KeychainService` is the production source;
/// tests inject a fake so they never touch the real Keychain.
protocol APIKeyProviding {
    func load() -> String?
}

extension KeychainService: APIKeyProviding {}

/// Runs an `AIAction` against the Claude Messages API via direct `URLSession`
/// (PRD §3, §F4). No SDK dependency; all business logic, no UI.
final class ClaudeService {
    private let keyProvider: APIKeyProviding
    private let session: URLSession

    private static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private static let model = "claude-haiku-4-5-20251001"
    private static let anthropicVersion = "2023-06-01"
    private static let maxTokens = 1024
    private static let maxInputCharacters = 4_000
    private static let timeout: TimeInterval = 30

    init(keyProvider: APIKeyProviding = KeychainService(), session: URLSession = .shared) {
        self.keyProvider = keyProvider
        self.session = session
    }

    func run(_ action: AIAction, on text: String) async throws -> String {
        guard let apiKey = keyProvider.load(), !apiKey.isEmpty else {
            throw AppError.missingAPIKey
        }

        // Store up to 10,000 chars (F1) but send at most 4,000 (F4) — different limits.
        let input = String(text.prefix(Self.maxInputCharacters))
        let request = try makeRequest(apiKey: apiKey, action: action, input: input)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw AppError.networkError
        }

        guard let http = response as? HTTPURLResponse else { throw AppError.networkError }
        switch http.statusCode {
        case 200: break
        case 401: throw AppError.invalidAPIKey
        case 429: throw AppError.rateLimited
        default: throw AppError.networkError
        }

        guard let output = Self.firstText(in: data) else { throw AppError.networkError }
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func makeRequest(apiKey: String, action: AIAction, input: String) throws -> URLRequest {
        var request = URLRequest(url: Self.endpoint, timeoutInterval: Self.timeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(Self.anthropicVersion, forHTTPHeaderField: "anthropic-version")

        let body = RequestBody(
            model: Self.model,
            max_tokens: Self.maxTokens,
            system: Prompts.system(for: action),
            messages: [.init(role: "user", content: input)]
        )
        request.httpBody = try JSONEncoder().encode(body)
        return request
    }

    private static func firstText(in data: Data) -> String? {
        guard let decoded = try? JSONDecoder().decode(ResponseBody.self, from: data) else {
            return nil
        }
        return decoded.content.first { $0.type == "text" }?.text
    }
}

private struct RequestBody: Encodable {
    let model: String
    let max_tokens: Int
    let system: String
    let messages: [Message]

    struct Message: Encodable {
        let role: String
        let content: String
    }
}

private struct ResponseBody: Decodable {
    let content: [Block]

    struct Block: Decodable {
        let type: String
        let text: String?
    }
}
