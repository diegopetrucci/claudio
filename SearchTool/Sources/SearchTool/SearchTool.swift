import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct SearchTool: Sendable {
    public var search: @Sendable (String, Int) async throws -> [SearchResult]

    public init(
        search: @escaping @Sendable (String, Int) async throws -> [SearchResult]
    ) {
        self.search = search
    }
}

extension SearchTool {
    public static func live(
        apiKey: String,
        endpoint: URL = URL(string: "https://api.search.brave.com/res/v1/web/search")!,
        httpClient: any SearchToolHTTPSession = URLSession.shared,
        jsonDecoder: JSONDecoder = JSONDecoder(),
    ) -> Self {
        .init(
            search: { query, maxResults in
                let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !normalizedQuery.isEmpty
                else { throw SearchToolError.invalidQuery }

                let clampedMaxResults = min(max(maxResults, 1), 20)
                var urlComponents = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
                urlComponents?.queryItems = [
                    .init(name: "q", value: normalizedQuery),
                    .init(name: "count", value: String(clampedMaxResults)),
                ]

                guard let requestURL = urlComponents?.url
                else { throw SearchToolError.invalidEndpoint }

                var request = URLRequest(url: requestURL)
                request.httpMethod = "GET"
                request.setValue("application/json", forHTTPHeaderField: "Accept")
                request.setValue(apiKey, forHTTPHeaderField: "X-Subscription-Token")

                let data: Data
                let rawResponse: URLResponse
                do {
                    (data, rawResponse) = try await httpClient.data(for: request)
                } catch {
                    throw SearchToolError.transportFailed(description: error.localizedDescription)
                }

                guard let response = rawResponse as? HTTPURLResponse
                else { throw SearchToolError.invalidResponse(description: "Non-HTTP response.") }

                guard (200..<300).contains(response.statusCode)
                else {
                    let responseBody = String(decoding: data.prefix(500), as: UTF8.self)
                    throw SearchToolError.unexpectedStatusCode(
                        statusCode: response.statusCode,
                        body: responseBody
                    )
                }

                let payload: SearchResponsePayload
                do {
                    payload = try jsonDecoder.decode(SearchResponsePayload.self, from: data)
                } catch {
                    throw SearchToolError.invalidResponse(description: error.localizedDescription)
                }

                return payload.results
            }
        )
    }
}
