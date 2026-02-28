import Foundation

public enum AnthropicClientError: Error {
    case missingTextContent
    case invalidToolUseResponse
    case toolLoopExceeded(maxRounds: Int)
    case unsupportedToolSchemaType(type: String, context: String)
}

extension AnthropicClientError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .missingTextContent:
            return "Anthropic response did not include text content."
        case .invalidToolUseResponse:
            return "Anthropic response requested tool use but did not include a valid assistant tool payload."
        case let .toolLoopExceeded(maxRounds):
            return "Anthropic tool loop exceeded max rounds (\(maxRounds))."
        case let .unsupportedToolSchemaType(type, context):
            return "Unsupported tool schema type '\(type)' for \(context)."
        }
    }
}
