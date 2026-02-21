@preconcurrency import SwiftAnthropic
import Foundation

public struct AnthropicClient: Sendable {
    public var generateText: @Sendable (String) async throws -> String
    
    public init(generateText: @Sendable @escaping (String) async throws -> String) {
        self.generateText = generateText
    }
}

extension AnthropicClient {
    static let defaultSystemPrompt = soul

    public static func live(
        apiKey: String,
        model: AnthropicModel,
        maxTokens: Int,
        loadSystemPrompt: (@Sendable () throws -> String)? = nil,
        createMessageOverride: (@Sendable (MessageParameter) async throws -> MessageResponse)? = nil
    ) -> Self {
        let loadSystemPrompt = loadSystemPrompt ?? {
            try Self.loadSystemPrompt()
        }
        guard let systemPrompt = try? loadSystemPrompt()
        else { fatalError("Failed to load system prompt. Ensure the system prompt file exists and is readable.") }
            
        let createMessage: @Sendable (MessageParameter) async throws -> MessageResponse
        if let injectedCreateMessage = createMessageOverride {
            createMessage = injectedCreateMessage
        } else {
            let service = AnthropicServiceFactory.service(
                apiKey: apiKey,
                betaHeaders: nil
            )
            createMessage = { parameter in
                try await service.createMessage(parameter)
            }
        }

        return .init(
            generateText: { prompt in
                let parameter = MessageParameter(
                    model: .other(model.apiValue),
                    messages: [
                        .init(role: .user, content: .text(prompt)),
                    ],
                    maxTokens: maxTokens,
                    system: .text(systemPrompt)
                )

                let response = try await createMessage(parameter)
                let text = response.content.compactMap { contentBlock -> String? in
                    if case let .text(blockText, _) = contentBlock {
                        return blockText
                    }
                    return nil
                }.joined()

                guard !text.isEmpty else {
                    throw AnthropicClientError.missingTextContent
                }

                return text
            }
        )
    }

    public static func ensureSystemPromptFileExists(filePath: String = "SOUL.md") throws {
        guard !FileManager.default.fileExists(atPath: filePath)
        else { return }

        let fileURL = URL(fileURLWithPath: filePath)
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try Self.defaultSystemPrompt.write(
                to: fileURL,
                atomically: true,
                encoding: .utf8
            )
        } catch {
            throw AnthropicClientError.unableToWriteSystemPromptFile(path: filePath, underlyingError: error)
        }
    }

    static func loadSystemPrompt(filePath: String = "SOUL.md") throws -> String {
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
}
