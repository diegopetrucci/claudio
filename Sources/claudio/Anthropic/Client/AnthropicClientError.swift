import Foundation

enum AnthropicClientError: Error {
    case missingTextContent
}

extension AnthropicClientError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .missingTextContent:
            return "Anthropic response did not include text content."
        }
    }
}

