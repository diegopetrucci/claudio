import AnthropicClient
import TelegramClient

struct TelegramBotService: Sendable {
    var handleIncomingText: @Sendable (Int64, String) async throws -> Void
}

extension TelegramBotService {
    static func live(
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
