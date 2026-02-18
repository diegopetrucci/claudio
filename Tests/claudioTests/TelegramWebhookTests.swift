@testable import claudio
import Testing
import VaporTesting

@Suite("TelegramWebhook Tests")
struct TelegramWebhookTests {
    @Test("webhook delegates user text to bot service")
    func webhookDelegatesToBotService() async throws {
        let recorder = BotServiceCallRecorder()

        try await withApp(configure: { app in
            app.telegramBotService = .init(
                handleIncomingText: { chatID, text in
                    await recorder.record(chatID: chatID, text: text)
                }
            )
            try routes(app)
        }, { app in
            let update = Self.makeUpdate(chatID: 101, text: "hello")

            try await app.testing().test(.POST, "telegram/webhook", beforeRequest: { req in
                try req.content.encode(update, as: .json)
            }, afterResponse: { res async in
                #expect(res.status == .ok)
            })
        })

        let calls = await recorder.all()
        #expect(calls == [BotServiceCall(chatID: 101, text: "hello")])
    }

    @Test("webhook ignores bot messages")
    func webhookIgnoresBotMessages() async throws {
        let recorder = BotServiceCallRecorder()

        try await withApp(configure: { app in
            app.telegramBotService = .init(
                handleIncomingText: { chatID, text in
                    await recorder.record(chatID: chatID, text: text)
                }
            )
            try routes(app)
        }, { app in
            let update = Self.makeUpdate(chatID: 101, text: "hello", isBot: true)

            try await app.testing().test(.POST, "telegram/webhook", beforeRequest: { req in
                try req.content.encode(update, as: .json)
            }, afterResponse: { res async in
                #expect(res.status == .ok)
            })
        })

        let calls = await recorder.all()
        #expect(calls.isEmpty)
    }

    @Test("webhook rejects invalid secret token")
    func webhookRejectsInvalidSecretToken() async throws {
        let recorder = BotServiceCallRecorder()

        try await withApp(configure: { app in
            app.telegramWebhookSecretToken = "expected-secret"
            app.telegramBotService = .init(
                handleIncomingText: { chatID, text in
                    await recorder.record(chatID: chatID, text: text)
                }
            )
            try routes(app)
        }, { app in
            let update = Self.makeUpdate(chatID: 101, text: "hello")

            try await app.testing().test(.POST, "telegram/webhook", beforeRequest: { req in
                try req.content.encode(update, as: .json)
                req.headers.replaceOrAdd(name: "X-Telegram-Bot-Api-Secret-Token", value: "wrong-secret")
            }, afterResponse: { res async in
                #expect(res.status == .unauthorized)
            })
        })

        let calls = await recorder.all()
        #expect(calls.isEmpty)
    }

    @Test("webhook accepts valid secret token")
    func webhookAcceptsValidSecretToken() async throws {
        let recorder = BotServiceCallRecorder()

        try await withApp(configure: { app in
            app.telegramWebhookSecretToken = "expected-secret"
            app.telegramBotService = .init(
                handleIncomingText: { chatID, text in
                    await recorder.record(chatID: chatID, text: text)
                }
            )
            try routes(app)
        }, { app in
            let update = Self.makeUpdate(chatID: 101, text: "hello")

            try await app.testing().test(.POST, "telegram/webhook", beforeRequest: { req in
                try req.content.encode(update, as: .json)
                req.headers.replaceOrAdd(name: "X-Telegram-Bot-Api-Secret-Token", value: "expected-secret")
            }, afterResponse: { res async in
                #expect(res.status == .ok)
            })
        })

        let calls = await recorder.all()
        #expect(calls == [BotServiceCall(chatID: 101, text: "hello")])
    }

    private static func makeUpdate(chatID: Int64, text: String, isBot: Bool = false) -> TelegramUpdate {
        TelegramUpdate(
            updateID: 999,
            message: TelegramMessage(
                messageID: 123,
                from: TelegramUser(id: 77, isBot: isBot),
                chat: TelegramChat(id: chatID),
                text: text
            )
        )
    }
}

private struct BotServiceCall: Equatable, Sendable {
    let chatID: Int64
    let text: String
}

private actor BotServiceCallRecorder {
    private var calls: [BotServiceCall] = []

    func record(chatID: Int64, text: String) {
        self.calls.append(BotServiceCall(chatID: chatID, text: text))
    }

    func all() -> [BotServiceCall] {
        self.calls
    }
}
