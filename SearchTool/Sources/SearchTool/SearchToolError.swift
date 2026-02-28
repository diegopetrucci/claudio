public enum SearchToolError: Error, Equatable {
    case invalidQuery
    case invalidEndpoint
    case transportFailed(description: String)
    case unexpectedStatusCode(statusCode: Int, body: String)
    case invalidResponse(description: String)
}
