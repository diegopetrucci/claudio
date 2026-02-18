import Foundation

public enum AnthropicClientError: Error {
    case missingTextContent
}

extension AnthropicClientError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .missingTextContent:
            return "Anthropic response did not include text content."
        }
    }
}

