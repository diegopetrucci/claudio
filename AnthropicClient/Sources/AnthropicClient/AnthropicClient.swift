@preconcurrency import SwiftAnthropic

public struct AnthropicClient: Sendable {
    public var generateText: @Sendable (String) async throws -> String
    
    public init(generateText: @escaping @Sendable (String) async throws -> String) {
        self.generateText = generateText
    }
}

extension AnthropicClient {
    public static func live(
        apiKey: String,
        model: AnthropicModel,
        maxTokens: Int,
        systemPrompt: String? = nil
    ) -> Self {
        let service = AnthropicServiceFactory.service(
            apiKey: apiKey,
            betaHeaders: nil
        )
        return .live(
            service: service,
            model: model,
            maxTokens: maxTokens,
            systemPrompt: systemPrompt
        )
    }

    static func live(
        service: any AnthropicService,
        model: AnthropicModel,
        maxTokens: Int,
        systemPrompt: String? = nil
    ) -> Self {
        .live(
            model: model,
            maxTokens: maxTokens,
            systemPrompt: systemPrompt,
            createMessage: { parameter in
                try await service.createMessage(parameter)
            }
        )
    }

    static func live(
        model: AnthropicModel,
        maxTokens: Int,
        systemPrompt: String? = nil,
        createMessage: @escaping @Sendable (MessageParameter) async throws -> MessageResponse
    ) -> Self {
        .init(
            generateText: { prompt in
                let parameter = MessageParameter(
                    model: .other(model.apiValue),
                    messages: [
                        .init(role: .user, content: .text(prompt)),
                    ],
                    maxTokens: maxTokens,
                    system: systemPrompt.map { .text($0) }
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
}
