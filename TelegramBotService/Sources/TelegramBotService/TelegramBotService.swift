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
                let history = try await sessionStore.loadSession(chatID)
                let promptLines = history.suffix(20).map { message in
                    switch message.role {
                    case .user:
                        return "User: \(message.text)"
                    case .assistant:
                        return "Assistant: \(message.text)"
                    }
                }
                let prompt = (promptLines + ["Assistant:"]).joined(separator: "\n")
                let generatedReply = try await anthropicClient.respond(
                    .init(text: prompt)
                )
                _ = try await telegramClient.sendMessage(chatID, generatedReply.text)
                try await sessionStore.appendMessage(
                    chatID,
                    .assistant,
                    generatedReply.text,
                    Date()
                )
            }
        )
    }
}
