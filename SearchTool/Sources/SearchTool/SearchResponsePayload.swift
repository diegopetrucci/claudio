import Foundation

struct SearchResponsePayload: Decodable {
    let web: WebResultContainer?

    var results: [SearchResult] {
        guard let webResults = web?.results
        else { return [] }

        var mappedResults: [SearchResult] = []
        mappedResults.reserveCapacity(webResults.count)
        for result in webResults {
            guard
                let title = result.title?.trimmingCharacters(in: .whitespacesAndNewlines),
                !title.isEmpty,
                let url = result.url?.trimmingCharacters(in: .whitespacesAndNewlines),
                !url.isEmpty
            else { continue }

            let description = result.description?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let fallbackSnippet = result.extraSnippets?.first?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let snippet: String
            if let description, !description.isEmpty {
                snippet = description
            } else if let fallbackSnippet, !fallbackSnippet.isEmpty {
                snippet = fallbackSnippet
            } else {
                snippet = ""
            }

            mappedResults.append(
                SearchResult(
                    title: title,
                    url: url,
                    snippet: snippet,
                    pageAge: result.pageAge
                )
            )
        }
        return mappedResults
    }

    struct WebResultContainer: Decodable {
        let results: [WebResult]?
    }

    struct WebResult: Decodable {
        let title: String?
        let url: String?
        let description: String?
        let extraSnippets: [String]?
        let pageAge: String?

        enum CodingKeys: String, CodingKey {
            case title
            case url
            case description
            case extraSnippets = "extra_snippets"
            case pageAge = "page_age"
        }
    }
}
