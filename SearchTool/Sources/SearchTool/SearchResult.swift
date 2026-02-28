public struct SearchResult: Codable, Equatable, Sendable {
    public let title: String
    public let url: String
    public let snippet: String
    public let pageAge: String?

    public init(
        title: String,
        url: String,
        snippet: String,
        pageAge: String?
    ) {
        self.title = title
        self.url = url
        self.snippet = snippet
        self.pageAge = pageAge
    }
}
