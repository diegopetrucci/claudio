import Testing
import TelegramClient
import Vapor
@testable import TelegramPollingLifecycleHandler

@Suite("TelegramPollingLifecycleHandler Tests")
struct TelegramPollingLifecycleHandlerTests {
    @Test("didBootAsync starts polling from persisted cursor")
    func didBootAsyncStartsPollingFromPersistedCursor() async throws {
        let offsetRecorder = OffsetRecorder()
        let handler = TelegramPollingLifecycleHandler(
            getUpdates: { offset, _ in
                await offsetRecorder.record(offset)
                try await Task.sleep(nanoseconds: 5_000_000)
                return []
            },
            handleIncomingText: { _, _ in },
            loadLastProcessedUpdateID: { 41 },
            saveLastProcessedUpdateID: { _ in },
            logger: Logger(label: "tests.polling.resume"),
            pollTimeoutSeconds: 1,
            retryDelayNanoseconds: 1_000_000
        )

        let app = try await Application.make(.testing)
        do {
            try await handler.didBootAsync(app)
            try await waitUntil {
                await offsetRecorder.first() != nil
            }

            let firstOffset = await offsetRecorder.first()
            #expect(firstOffset == 42)

            await handler.shutdownAsync(app)
            try await app.asyncShutdown()
        } catch {
            try? await app.asyncShutdown()
            throw error
        }
    }

    @Test("didBootAsync persists cursor after processing updates")
    func didBootAsyncPersistsCursorAfterProcessingUpdates() async throws {
        let savedUpdateIDRecorder = SavedUpdateIDRecorder()
        let handler = TelegramPollingLifecycleHandler(
            getUpdates: { _, _ in
                [
                    TelegramUpdate(
                        updateID: 7,
                        message: TelegramMessage(
                            messageID: 1,
                            from: TelegramUser(id: 2, isBot: false),
                            chat: TelegramChat(id: 101),
                            text: "hello"
                        )
                    ),
                ]
            },
            handleIncomingText: { _, _ in },
            loadLastProcessedUpdateID: { nil },
            saveLastProcessedUpdateID: { updateID in
                await savedUpdateIDRecorder.record(updateID)
            },
            logger: Logger(label: "tests.polling.persist"),
            pollTimeoutSeconds: 1,
            retryDelayNanoseconds: 1_000_000
        )

        let app = try await Application.make(.testing)
        do {
            try await handler.didBootAsync(app)
            try await waitUntil {
                await savedUpdateIDRecorder.contains(7)
            }

            #expect(await savedUpdateIDRecorder.contains(7))

            await handler.shutdownAsync(app)
            try await app.asyncShutdown()
        } catch {
            try? await app.asyncShutdown()
            throw error
        }
    }
}

private actor OffsetRecorder {
    private var offsets: [Int?] = []

    func record(_ offset: Int?) {
        self.offsets.append(offset)
    }

    func first() -> Int? {
        self.offsets.first ?? nil
    }
}

private actor SavedUpdateIDRecorder {
    private var updateIDs: [Int] = []

    func record(_ updateID: Int) {
        self.updateIDs.append(updateID)
    }

    func contains(_ updateID: Int) -> Bool {
        self.updateIDs.contains(updateID)
    }
}

private func waitUntil(
    timeoutNanoseconds: UInt64 = 1_000_000_000,
    intervalNanoseconds: UInt64 = 10_000_000,
    condition: @escaping @Sendable () async -> Bool
) async throws {
    let deadline = ContinuousClock.now.advanced(by: .nanoseconds(Int64(timeoutNanoseconds)))

    while ContinuousClock.now < deadline {
        if await condition() {
            return
        }
        try await Task.sleep(nanoseconds: intervalNanoseconds)
    }

    throw WaitUntilError.timeout
}

private enum WaitUntilError: Error {
    case timeout
}
