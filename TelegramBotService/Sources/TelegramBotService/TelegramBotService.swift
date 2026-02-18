import AnthropicClient
import TelegramClient

public struct TelegramBotService: Sendable {
    public var handleIncomingText: @Sendable (Int64, String) async throws -> Void

    public init(
        handleIncomingText: @escaping @Sendable (Int64, String) async throws -> Void
    ) {
        self.handleIncomingText = handleIncomingText
    }
}

extension TelegramBotService {
    public static func live(
        anthropicClient: AnthropicClient,
        telegramClient: TelegramClient
    ) -> Self {
        .init(
            handleIncomingText: { chatID, text in
                let generatedReply = try await anthropicClient.generateText(text)
                _ = try await telegramClient.sendMessage(chatID, generatedReply)
            }
        )
    }
}
