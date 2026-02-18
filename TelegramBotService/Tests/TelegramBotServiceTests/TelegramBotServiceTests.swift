import Testing
import AnthropicClient
import TelegramClient
@testable import TelegramBotService

@Suite("TelegramBotService Tests")
struct TelegramBotServiceTests {
    @Test("handleIncomingText generates AI response and sends it to chat")
    func handleIncomingTextSuccess() async throws {
        let promptRecorder = PromptRecorder()
        let sendRecorder = TelegramSendRecorder()

        let anthropicClient = AnthropicClient(
            generateText: { prompt in
                await promptRecorder.record(prompt)
                return "AI: \(prompt)"
            }
        )
        let telegramClient = TelegramClient(
            sendMessage: { chatID, text in
                await sendRecorder.record(chatID: chatID, text: text)
                return TelegramSentMessage(messageID: 1)
            },
            getUpdates: { _, _ in
                []
            }
        )
        let service = TelegramBotService.live(
            anthropicClient: anthropicClient,
            telegramClient: telegramClient
        )

        try await service.handleIncomingText(101, "hello")

        let prompts = await promptRecorder.all()
        #expect(prompts == ["hello"])
        let calls = await sendRecorder.allCalls()
        #expect(calls == [BotServiceSendCall(chatID: 101, text: "AI: hello")])
    }

    @Test("handleIncomingText propagates anthropic failures")
    func handleIncomingTextAnthropicFailure() async throws {
        let sendRecorder = TelegramSendRecorder()

        let anthropicClient = AnthropicClient(
            generateText: { _ in
                throw StubError.failed
            }
        )
        let telegramClient = TelegramClient(
            sendMessage: { chatID, text in
                await sendRecorder.record(chatID: chatID, text: text)
                return TelegramSentMessage(messageID: 1)
            },
            getUpdates: { _, _ in
                []
            }
        )
        let service = TelegramBotService.live(
            anthropicClient: anthropicClient,
            telegramClient: telegramClient
        )

        do {
            try await service.handleIncomingText(101, "hello")
            Issue.record("Expected failure, but call succeeded.")
        } catch let error as StubError {
            #expect(error == .failed)
        }

        let calls = await sendRecorder.allCalls()
        #expect(calls.isEmpty)
    }
}

private enum StubError: Error {
    case failed
}

private actor PromptRecorder {
    private var prompts: [String] = []

    func record(_ prompt: String) {
        self.prompts.append(prompt)
    }

    func all() -> [String] {
        self.prompts
    }
}

private actor TelegramSendRecorder {
    private var calls: [BotServiceSendCall] = []

    func record(chatID: Int64, text: String) {
        self.calls.append(BotServiceSendCall(chatID: chatID, text: text))
    }

    func allCalls() -> [BotServiceSendCall] {
        self.calls
    }
}

private struct BotServiceSendCall: Equatable, Sendable {
    let chatID: Int64
    let text: String
}
