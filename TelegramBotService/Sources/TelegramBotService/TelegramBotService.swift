import Foundation
import AnthropicClient
import SessionStore
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
        telegramClient: TelegramClient,
        sessionStore: SessionStore
    ) -> Self {
        .init(
            handleIncomingText: { chatID, text in
                try await sessionStore.appendMessage(
                    chatID,
                    .user,
                    text,
                    Date()
                )
                let generatedReply = try await anthropicClient.generateText(text)
                try await sessionStore.appendMessage(
                    chatID,
                    .assistant,
                    generatedReply,
                    Date()
                )
                _ = try await telegramClient.sendMessage(chatID, generatedReply)
            }
        )
    }
}
