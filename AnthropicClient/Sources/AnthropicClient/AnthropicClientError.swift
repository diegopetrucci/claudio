import Foundation

public enum AnthropicClientError: Error {
    case missingTextContent
    case invalidToolUseResponse
    case toolLoopExceeded(maxRounds: Int)
    case unsupportedToolSchemaType(type: String, context: String)
    case emptySystemPromptFile(path: String)
    case unableToWriteSystemPromptFile(path: String, underlyingError: Error)
    case unableToReadSystemPromptFile(path: String, underlyingError: Error)
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
        case let .emptySystemPromptFile(path):
            return "System prompt file at \(path) is empty."
        case let .unableToWriteSystemPromptFile(path, underlyingError):
            return "Unable to write system prompt file at \(path): \(underlyingError.localizedDescription)"
        case let .unableToReadSystemPromptFile(path, underlyingError):
            return "Unable to read system prompt file at \(path): \(underlyingError.localizedDescription)"
        }
    }
}
