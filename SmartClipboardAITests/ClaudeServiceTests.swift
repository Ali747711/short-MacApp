import XCTest
@testable import SmartClipboardAI

/// Intercepts URLSession requests so `ClaudeService` can be tested without the
/// real network (PRD §Testing).
final class MockURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        guard let handler = MockURLProtocol.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
}

private struct FakeKeyProvider: APIKeyProviding {
    let key: String?
    func load() -> String? { key }
}

final class ClaudeServiceTests: XCTestCase {
    private func makeService(key: String? = "test-key") -> ClaudeService {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        return ClaudeService(keyProvider: FakeKeyProvider(key: key), session: session)
    }

    private func response(_ status: Int) -> HTTPURLResponse {
        HTTPURLResponse(
            url: URL(string: "https://api.anthropic.com/v1/messages")!,
            statusCode: status,
            httpVersion: nil,
            headerFields: nil
        )!
    }

    override func tearDown() {
        MockURLProtocol.handler = nil
        super.tearDown()
    }

    func testSuccessReturnsTrimmedText() async throws {
        MockURLProtocol.handler = { [self] _ in
            let body = #"{"content":[{"type":"text","text":"  안녕하세요  "}]}"#
            return (response(200), Data(body.utf8))
        }
        let output = try await makeService().run(.translate, on: "hello")
        XCTAssertEqual(output, "안녕하세요")
    }

    func testMissingKeyThrowsBeforeNetwork() async {
        MockURLProtocol.handler = { _ in XCTFail("should not hit network"); throw URLError(.cancelled) }
        await assertThrows(.missingAPIKey) {
            _ = try await makeService(key: nil).run(.clean, on: "text")
        }
    }

    func testUnauthorizedMapsToInvalidKey() async {
        MockURLProtocol.handler = { [self] _ in (response(401), Data("{}".utf8)) }
        await assertThrows(.invalidAPIKey) {
            _ = try await makeService().run(.summarize, on: "text")
        }
    }

    func testTooManyRequestsMapsToRateLimited() async {
        MockURLProtocol.handler = { [self] _ in (response(429), Data("{}".utf8)) }
        await assertThrows(.rateLimited) {
            _ = try await makeService().run(.translate, on: "text")
        }
    }

    func testTimeoutMapsToNetworkError() async {
        MockURLProtocol.handler = { _ in throw URLError(.timedOut) }
        await assertThrows(.networkError) {
            _ = try await makeService().run(.translate, on: "text")
        }
    }

    // MARK: - Helper

    private func assertThrows(
        _ expected: AppError,
        _ body: () async throws -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            try await body()
            XCTFail("expected \(expected)", file: file, line: line)
        } catch let error as AppError {
            XCTAssertEqual(error, expected, file: file, line: line)
        } catch {
            XCTFail("unexpected error \(error)", file: file, line: line)
        }
    }
}
