@preconcurrency import SwiftAnthropic
import Foundation
import ToolExecutor

public struct AnthropicClient: Sendable {
    public var respond: @Sendable (OutgoingMessage) async throws -> IncomingMessage
    public var ensureSystemPromptFileExists: @Sendable (String) throws -> Void
    
    public init(
        respond: @Sendable @escaping (OutgoingMessage) async throws -> IncomingMessage,
        ensureSystemPromptFileExists: @Sendable @escaping (String) throws -> Void = { _ in }
    ) {
        self.respond = respond
        self.ensureSystemPromptFileExists = ensureSystemPromptFileExists
    }
}

extension AnthropicClient {
    static let defaultSystemPrompt = soul

    public static func live(
        apiKey: String,
        model: AnthropicModel,
        maxTokens: Int,
        toolExecutor: ToolExecutor = .live(),
        runCommandTimeout: TimeInterval = 30,
        loadSystemPrompt: (@Sendable () throws -> String)? = nil,
        createMessageOverride: (@Sendable (MessageParameter) async throws -> MessageResponse)? = nil
    ) -> Self {
        let systemPrompt = resolvedSystemPrompt(loadSystemPrompt: loadSystemPrompt)
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
                        try executeToolUse(
                            toolUse,
                            toolExecutor: toolExecutor,
                            runCommandTimeout: runCommandTimeout
                        )
                    }
                )
            },
            ensureSystemPromptFileExists: { filePath in
                try writeDefaultSystemPromptIfMissing(
                    filePath: filePath,
                    defaultSystemPrompt: Self.defaultSystemPrompt
                )
            }
        )
    }

}

private func resolvedSystemPrompt(
    loadSystemPrompt: (@Sendable () throws -> String)?
) -> String {
    let loadSystemPrompt = loadSystemPrompt ?? {
        let filePath = "SOUL.md"
        do {
            let prompt = try String(contentsOfFile: filePath, encoding: .utf8)
            guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else {
                throw AnthropicClientError.emptySystemPromptFile(path: filePath)
            }
            return prompt
        } catch {
            if let anthropicError = error as? AnthropicClientError {
                throw anthropicError
            }
            throw AnthropicClientError.unableToReadSystemPromptFile(path: filePath, underlyingError: error)
        }
    }
    guard let systemPrompt = try? loadSystemPrompt()
    else { fatalError("Failed to load system prompt. Ensure the system prompt file exists and is readable.") }
    return systemPrompt
}

private func writeDefaultSystemPromptIfMissing(
    filePath: String,
    defaultSystemPrompt: String
) throws {
    guard !FileManager.default.fileExists(atPath: filePath)
    else { return }

    let fileURL = URL(fileURLWithPath: filePath)
    do {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try defaultSystemPrompt.write(
            to: fileURL,
            atomically: true,
            encoding: .utf8
        )
    } catch {
        throw AnthropicClientError.unableToWriteSystemPromptFile(path: filePath, underlyingError: error)
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
) throws -> String {
    switch toolUse.name {
    case AvailableTools.runCommand.name:
        let command = try requiredStringInput("command", in: toolUse.input)
        return try toolExecutor.runCommand(command, runCommandTimeout)
    case AvailableTools.readFile.name:
        let path = try requiredStringInput("path", in: toolUse.input)
        return try toolExecutor.readFile(path)
    case AvailableTools.writeFile.name:
        let path = try requiredStringInput("path", in: toolUse.input)
        let content = try requiredStringInput("content", in: toolUse.input)
        try toolExecutor.writeFile(path, content)
        return "Wrote file at path: \(path)"
    case AvailableTools.webSearch.name:
        let query = try requiredStringInput("query", in: toolUse.input)
        return try toolExecutor.webSearch(query)
    default:
        throw ToolExecutionInputError.unsupportedTool(name: toolUse.name)
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
    executeToolUse: @Sendable (MessageResponse.Content.ToolUse) throws -> String
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
                let output = try executeToolUse(toolUse)
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
