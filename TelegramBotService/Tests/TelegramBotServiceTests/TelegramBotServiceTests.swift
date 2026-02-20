import Foundation
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
        let sessionRecorder = SessionStoreRecorder()

        let anthropicClient = AnthropicClient(
            generateText: { prompt in
                await promptRecorder.record(prompt)
                return "AI reply"
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
        let sessionStore = makeSessionStore(sessionRecorder)
        let service = TelegramBotService.live(
            anthropicClient: anthropicClient,
            telegramClient: telegramClient,
            sessionStore: sessionStore
        )

        try await service.handleIncomingText(101, "hello")

        let prompts = await promptRecorder.all()
        #expect(prompts == ["User: hello\nAssistant:"])
        let calls = await sendRecorder.allCalls()
        #expect(calls == [BotServiceSendCall(chatID: 101, text: "AI reply")])
        let sessionCalls = await sessionRecorder.allCalls()
        #expect(
            sessionCalls == [
                SessionAppendCall(chatID: 101, role: .user, text: "hello"),
                SessionAppendCall(chatID: 101, role: .assistant, text: "AI reply"),
            ]
        )
    }

    @Test("handleIncomingText propagates anthropic failures")
    func handleIncomingTextAnthropicFailure() async throws {
        let promptRecorder = PromptRecorder()
        let sendRecorder = TelegramSendRecorder()
        let sessionRecorder = SessionStoreRecorder()

        let anthropicClient = AnthropicClient(
            generateText: { prompt in
                await promptRecorder.record(prompt)
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
        let sessionStore = makeSessionStore(sessionRecorder)
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

        let prompts = await promptRecorder.all()
        #expect(prompts == ["User: hello\nAssistant:"])
        let calls = await sendRecorder.allCalls()
        #expect(calls.isEmpty)
        let sessionCalls = await sessionRecorder.allCalls()
        #expect(sessionCalls == [SessionAppendCall(chatID: 101, role: .user, text: "hello")])
    }

    @Test("handleIncomingText includes previous session history in generated prompt")
    func handleIncomingTextIncludesSessionHistory() async throws {
        let promptRecorder = PromptRecorder()
        let sendRecorder = TelegramSendRecorder()
        let sessionRecorder = SessionStoreRecorder(
            initialHistoryByChatID: [
                101: [
                    SessionMessage(
                        role: .user,
                        text: "old question",
                        timestamp: Date(timeIntervalSince1970: 100)
                    ),
                    SessionMessage(
                        role: .assistant,
                        text: "old answer",
                        timestamp: Date(timeIntervalSince1970: 200)
                    ),
                ],
            ]
        )

        let anthropicClient = AnthropicClient(
            generateText: { prompt in
                await promptRecorder.record(prompt)
                return "AI reply"
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
            telegramClient: telegramClient,
            sessionStore: makeSessionStore(sessionRecorder)
        )

        try await service.handleIncomingText(101, "follow up")

        let prompts = await promptRecorder.all()
        #expect(
            prompts == [
                """
                User: old question
                Assistant: old answer
                User: follow up
                Assistant:
                """,
            ]
        )
        let sends = await sendRecorder.allCalls()
        #expect(sends == [BotServiceSendCall(chatID: 101, text: "AI reply")])
    }

    @Test("handleIncomingText does not persist assistant response when send fails")
    func handleIncomingTextSendFailure() async throws {
        let promptRecorder = PromptRecorder()
        let sessionRecorder = SessionStoreRecorder()

        let anthropicClient = AnthropicClient(
            generateText: { prompt in
                await promptRecorder.record(prompt)
                return "AI reply"
            }
        )
        let telegramClient = TelegramClient(
            sendMessage: { _, _ in
                throw StubError.failed
            },
            getUpdates: { _, _ in
                []
            }
        )
        let service = TelegramBotService.live(
            anthropicClient: anthropicClient,
            telegramClient: telegramClient,
            sessionStore: makeSessionStore(sessionRecorder)
        )

        do {
            try await service.handleIncomingText(101, "hello")
            Issue.record("Expected failure, but call succeeded.")
        } catch let error as StubError {
            #expect(error == .failed)
        }

        let prompts = await promptRecorder.all()
        #expect(prompts == ["User: hello\nAssistant:"])
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

private struct BotServiceSendCall: Equatable, Sendable {
    let chatID: Int64
    let text: String
}

private struct SessionAppendCall: Equatable, Sendable {
    let chatID: Int64
    let role: SessionMessageRole
    let text: String
}

private actor SessionStoreRecorder {
    private var historyByChatID: [Int64: [SessionMessage]]
    private var calls: [SessionAppendCall] = []

    init(initialHistoryByChatID: [Int64: [SessionMessage]] = [:]) {
        self.historyByChatID = initialHistoryByChatID
    }

    func loadSession(chatID: Int64) -> [SessionMessage] {
        self.historyByChatID[chatID] ?? []
    }

    func appendMessage(
        chatID: Int64,
        role: SessionMessageRole,
        text: String,
        timestamp: Date
    ) {
        self.historyByChatID[chatID, default: []].append(
            SessionMessage(
                role: role,
                text: text,
                timestamp: timestamp
            )
        )
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

private func makeSessionStore(
    _ recorder: SessionStoreRecorder
) -> SessionStore {
    SessionStore(
        loadSession: { chatID in
            await recorder.loadSession(chatID: chatID)
        },
        appendMessage: { chatID, role, text, timestamp in
            await recorder.appendMessage(
                chatID: chatID,
                role: role,
                text: text,
                timestamp: timestamp
            )
        },
        loadLastProcessedUpdateID: { nil },
        saveLastProcessedUpdateID: { _ in },
        flush: {}
    )
}
