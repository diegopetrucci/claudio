import Testing
import AnthropicClient
import SessionStore
import TelegramClient
@testable import TelegramBotService

@Suite("TelegramBotService Tests")
struct TelegramBotServiceTests {
    @Test("handleIncomingText generates AI response and sends it to chat")
    func handleIncomingTextSuccess() async throws {
        let promptRecorder = PromptRecorder()
        let sendRecorder = TelegramSendRecorder()
        let sessionRecorder = SessionAppendRecorder()

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
        let sessionStore = SessionStore(
            loadSession: { _ in [] },
            appendMessage: { chatID, role, text, _ in
                await sessionRecorder.record(chatID: chatID, role: role, text: text)
            },
            loadLastProcessedUpdateID: { nil },
            saveLastProcessedUpdateID: { _ in }
        )
        let service = TelegramBotService.live(
            anthropicClient: anthropicClient,
            telegramClient: telegramClient,
            sessionStore: sessionStore
        )

        try await service.handleIncomingText(101, "hello")

        let prompts = await promptRecorder.all()
        #expect(prompts == ["hello"])
        let calls = await sendRecorder.allCalls()
        #expect(calls == [BotServiceSendCall(chatID: 101, text: "AI: hello")])
        let sessionCalls = await sessionRecorder.allCalls()
        #expect(
            sessionCalls == [
                SessionAppendCall(chatID: 101, role: .user, text: "hello"),
                SessionAppendCall(chatID: 101, role: .assistant, text: "AI: hello"),
            ]
        )
    }

    @Test("handleIncomingText propagates anthropic failures")
    func handleIncomingTextAnthropicFailure() async throws {
        let sendRecorder = TelegramSendRecorder()
        let sessionRecorder = SessionAppendRecorder()

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
        let sessionStore = SessionStore(
            loadSession: { _ in [] },
            appendMessage: { chatID, role, text, _ in
                await sessionRecorder.record(chatID: chatID, role: role, text: text)
            },
            loadLastProcessedUpdateID: { nil },
            saveLastProcessedUpdateID: { _ in }
        )
        let service = TelegramBotService.live(
            anthropicClient: anthropicClient,
            telegramClient: telegramClient,
            sessionStore: sessionStore
        )

        do {
            try await service.handleIncomingText(101, "hello")
            Issue.record("Expected failure, but call succeeded.")
        } catch let error as StubError {
            #expect(error == .failed)
        }

        let calls = await sendRecorder.allCalls()
        #expect(calls.isEmpty)
        let sessionCalls = await sessionRecorder.allCalls()
        #expect(sessionCalls == [SessionAppendCall(chatID: 101, role: .user, text: "hello")])
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

private actor SessionAppendRecorder {
    private var calls: [SessionAppendCall] = []

    func record(chatID: Int64, role: SessionMessageRole, text: String) {
        self.calls.append(
            SessionAppendCall(
                chatID: chatID,
                role: role,
                text: text
            )
        )
    }

    func allCalls() -> [SessionAppendCall] {
        self.calls
    }
}

private struct BotServiceSendCall: Equatable, Sendable {
    let chatID: Int64
    let text: String
}

private struct SessionAppendCall: Equatable, Sendable {
    let chatID: Int64
    let role: SessionMessageRole
    let text: String
}
