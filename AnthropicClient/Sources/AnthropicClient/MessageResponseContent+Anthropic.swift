@preconcurrency import SwiftAnthropic

extension MessageResponse.Content {
    var toMessageContentObject: MessageParameter.Message.Content.ContentObject? {
        switch self {
        case let .text(text, _):
            return .text(text)
        case let .toolUse(toolUse):
            return .toolUse(toolUse.id, toolUse.name, toolUse.input)
        case let .thinking(thinking):
            guard let signature = thinking.signature
            else { return nil }
            return .thinking(thinking.thinking, signature)
        case .serverToolUse, .webSearchToolResult, .toolResult, .codeExecutionToolResult:
            return nil
        }
    }
}
