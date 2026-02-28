import Foundation
import Testing
@testable import SearchTool

@Suite("SearchTool Tests")
struct SearchToolTests {
    @Test("live search sets headers and query parameters")
    func liveSearchBuildsExpectedRequest() async throws {
        let session = MockHTTPSession(
            responseData: Data(#"{"web":{"results":[]}}"#.utf8),
            statusCode: 200
        )
        let client = SearchTool.live(
            apiKey: "secret-key",
            httpClient: session
        )

        _ = try await client.search("swift concurrency", 7)

        let request = await session.lastRequest()
        #expect(request?.httpMethod == "GET")
        #expect(request?.value(forHTTPHeaderField: "X-Subscription-Token") == "secret-key")
        #expect(request?.value(forHTTPHeaderField: "Accept") == "application/json")
        #expect(request?.url?.host == "api.search.brave.com")
        guard let request, let requestURL = request.url else {
            Issue.record("Expected captured request with URL.")
            return
        }
        let queryItems = URLComponents(url: requestURL, resolvingAgainstBaseURL: false)?.queryItems
        #expect(queryItems?.first(where: { $0.name == "q" })?.value == "swift concurrency")
        #expect(queryItems?.first(where: { $0.name == "count" })?.value == "7")
    }

    @Test("live search decodes web results")
    func liveSearchDecodesResults() async throws {
        let payload = #"""
            {
              "web": {
                "results": [
                  {
                    "title": "Swift Concurrency",
                    "url": "https://example.com/swift-concurrency",
                    "description": "Structured concurrency overview",
                    "extra_snippets": ["extra"],
                    "page_age": "2025-12-01T10:00:00Z"
                  }
                ]
              }
            }
            """#

        let session = MockHTTPSession(
            responseData: Data(payload.utf8),
            statusCode: 200
        )
        let client = SearchTool.live(
            apiKey: "secret-key",
            httpClient: session
        )

        let results = try await client.search("swift", 5)

        #expect(results == [
            .init(
                title: "Swift Concurrency",
                url: "https://example.com/swift-concurrency",
                snippet: "Structured concurrency overview",
                pageAge: "2025-12-01T10:00:00Z"
            ),
        ])
    }

    @Test("live search maps non-2xx response")
    func liveSearchMapsErrorResponse() async throws {
        let session = MockHTTPSession(
            responseData: Data("rate limited".utf8),
            statusCode: 429
        )
        let client = SearchTool.live(
            apiKey: "secret-key",
            httpClient: session
        )

        do {
            _ = try await client.search("swift", 5)
            Issue.record("Expected unexpectedStatusCode error, but call succeeded.")
        } catch let error as SearchToolError {
            switch error {
            case let .unexpectedStatusCode(statusCode, body):
                #expect(statusCode == 429)
                #expect(body == "rate limited")
            default:
                Issue.record("Expected unexpectedStatusCode error, but got \(error).")
            }
        }
    }

    @Test("live search maps non-http response")
    func liveSearchMapsNonHTTPResponse() async throws {
        let session = MockHTTPSession(
            responseData: Data(#"{"web":{"results":[]}}"#.utf8),
            response: URLResponse(
                url: URL(string: "https://example.com")!,
                mimeType: "application/json",
                expectedContentLength: 0,
                textEncodingName: "utf-8"
            )
        )
        let client = SearchTool.live(
            apiKey: "secret-key",
            httpClient: session
        )

        do {
            _ = try await client.search("swift", 5)
            Issue.record("Expected invalidResponse error, but call succeeded.")
        } catch let error as SearchToolError {
            switch error {
            case let .invalidResponse(description):
                #expect(description == "Non-HTTP response.")
            default:
                Issue.record("Expected invalidResponse error, but got \(error).")
            }
        }
    }
}

private actor MockHTTPSession: SearchToolHTTPSession {
    private let responseData: Data
    private let response: URLResponse
    private(set) var capturedRequest: URLRequest?

    init(
        responseData: Data,
        statusCode: Int
    ) {
        self.responseData = responseData
        self.response = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
    }

    init(
        responseData: Data,
        response: URLResponse
    ) {
        self.responseData = responseData
        self.response = response
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        self.capturedRequest = request
        return (self.responseData, self.response)
    }

    func lastRequest() -> URLRequest? {
        self.capturedRequest
    }
}
