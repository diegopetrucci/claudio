@preconcurrency import SwiftAnthropic
import Foundation
import ToolExecutor

public struct AnthropicClient: Sendable {
    public var respond: @Sendable (OutgoingMessage) async throws -> IncomingMessage
    
    public init(
        respond: @Sendable @escaping (OutgoingMessage) async throws -> IncomingMessage
    ) {
        self.respond = respond
    }
}

extension AnthropicClient {
    public static func live(
        apiKey: String,
        model: AnthropicModel,
        maxTokens: Int,
        systemPrompt: String,
        toolExecutor: ToolExecutor = .live(),
        runCommandTimeout: TimeInterval = 30,
        createMessageOverride: (@Sendable (MessageParameter) async throws -> MessageResponse)? = nil
    ) -> Self {
        let createMessage = resolvedCreateMessage(
            apiKey: apiKey,
            createMessageOverride: createMessageOverride
        )

        return .init(
            respond: { outgoingMessage in
                try await respondToOutgoingMessage(
                    outgoingMessage: outgoingMessage,
                    model: model,
                    maxTokens: maxTokens,
                    systemPrompt: systemPrompt,
                    maxToolRounds: 6,
                    createMessage: createMessage,
                    executeToolUse: { toolUse in
                        try await executeToolUse(
                            toolUse,
                            toolExecutor: toolExecutor,
                            runCommandTimeout: runCommandTimeout
                        )
                    }
                )
            }
        )
    }

}

private func resolvedCreateMessage(
    apiKey: String,
    createMessageOverride: (@Sendable (MessageParameter) async throws -> MessageResponse)?
) -> @Sendable (MessageParameter) async throws -> MessageResponse {
    if let injectedCreateMessage = createMessageOverride {
        return injectedCreateMessage
    }

    let service = AnthropicServiceFactory.service(
        apiKey: apiKey,
        betaHeaders: nil
    )
    return { parameter in
        try await service.createMessage(parameter)
    }
}

private func executeToolUse(
    _ toolUse: MessageResponse.Content.ToolUse,
    toolExecutor: ToolExecutor,
    runCommandTimeout: TimeInterval
) async throws -> String {
    guard let tool = AvailableTools(rawValue: toolUse.name)
    else { throw ToolExecutionInputError.unsupportedTool(name: toolUse.name) }

    switch tool {
    case .runCommand:
        let command = try requiredStringInput("command", in: toolUse.input)
        return try toolExecutor.runCommand(command, runCommandTimeout)
    case .readFile:
        let path = try requiredStringInput("path", in: toolUse.input)
        return try toolExecutor.readFile(path)
    case .writeFile:
        let path = try requiredStringInput("path", in: toolUse.input)
        let content = try requiredStringInput("content", in: toolUse.input)
        try toolExecutor.writeFile(path, content)
        return "Wrote file at path: \(path)"
    case .webSearch:
        let query = try requiredStringInput("query", in: toolUse.input)
        return try await toolExecutor.webSearch(query)
    }
}

private func requiredStringInput(
    _ key: String,
    in input: MessageResponse.Content.Input
) throws -> String {
    guard let value = input[key]
    else { throw ToolExecutionInputError.missingRequiredInput(name: key) }
    
    guard case let .string(stringValue) = value
    else {
        throw ToolExecutionInputError.invalidInputType(
            name: key,
            expected: "string",
            actual: String(describing: value)
        )
    }
    
    return stringValue
}

private let maxToolResultCharacters = 8_000

private func sanitizeToolOutput(_ output: String) -> String {
    guard output.count > maxToolResultCharacters
    else { return output }
    
    let prefix = output.prefix(maxToolResultCharacters)
    return "\(prefix)\n...[truncated]"
}

private enum ToolExecutionInputError: LocalizedError {
    case missingRequiredInput(name: String)
    case invalidInputType(name: String, expected: String, actual: String)
    case unsupportedTool(name: String)
    
    var errorDescription: String? {
        switch self {
        case let .missingRequiredInput(name):
            return "Missing required input '\(name)'."
        case let .invalidInputType(name, expected, actual):
            return "Invalid type for input '\(name)'. Expected \(expected), got \(actual)."
        case let .unsupportedTool(name):
            return "Unsupported tool '\(name)'."
        }
    }
}

private func respondToOutgoingMessage(
    outgoingMessage: OutgoingMessage,
    model: AnthropicModel,
    maxTokens: Int,
    systemPrompt: String,
    maxToolRounds: Int,
    createMessage: @Sendable (MessageParameter) async throws -> MessageResponse,
    executeToolUse: @Sendable (MessageResponse.Content.ToolUse) async throws -> String
) async throws -> IncomingMessage {
    var messages: [MessageParameter.Message] = [
        .init(role: .user, content: .text(outgoingMessage.text)),
    ]
    let anthropicTools = try tools.map { try $0.toAnthropicTool }
    
    var toolRoundCount = 0
    while true {
        let parameter = MessageParameter(
            model: .other(model.apiValue),
            messages: messages,
            maxTokens: maxTokens,
            system: .text(systemPrompt),
            tools: anthropicTools.isEmpty ? nil : anthropicTools
        )
        
        let response = try await createMessage(parameter)
        
        let toolUses = response.content.compactMap { contentBlock -> MessageResponse.Content.ToolUse? in
            if case let .toolUse(toolUse) = contentBlock {
                return toolUse
            } else {
                return nil
            }
        }
        
        guard !toolUses.isEmpty
        else {
            let text = response.content.compactMap { contentBlock -> String? in
                if case let .text(blockText, _) = contentBlock {
                    return blockText
                } else {
                    return nil
                }
            }.joined()
            
            guard !text.isEmpty
            else { throw AnthropicClientError.missingTextContent }
            
            return .init(text: text)
        }
        
        toolRoundCount += 1
        guard toolRoundCount <= maxToolRounds
        else { throw AnthropicClientError.toolLoopExceeded(maxRounds: maxToolRounds) }
        
        let assistantContent = response.content.compactMap { contentBlock in
            contentBlock.toMessageContentObject
        }
        guard !assistantContent.isEmpty
        else { throw AnthropicClientError.invalidToolUseResponse }
        messages.append(
            .init(
                role: .assistant,
                content: .list(assistantContent)
            )
        )
        
        var toolResults: [MessageParameter.Message.Content.ContentObject] = []
        toolResults.reserveCapacity(toolUses.count)
        for toolUse in toolUses {
            do {
                let output = try await executeToolUse(toolUse)
                toolResults.append(
                    .toolResult(
                        toolUse.id,
                        sanitizeToolOutput(output),
                        isError: false
                    )
                )
            } catch {
                toolResults.append(
                    .toolResult(
                        toolUse.id,
                        sanitizeToolOutput("Tool execution failed: \(error.localizedDescription)"),
                        isError: true
                    )
                )
            }
        }
        
        messages.append(
            .init(
                role: .user,
                content: .list(toolResults)
            )
        )
    }
}
