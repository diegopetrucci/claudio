import Vapor
import TelegramClient

public final class TelegramPollingLifecycleHandler: LifecycleHandler, @unchecked Sendable {
    let getUpdates: @Sendable (Int?, Int) async throws -> [TelegramUpdate]
    let handleIncomingText: @Sendable (Int64, String) async throws -> Void
    let loadLastProcessedUpdateID: @Sendable () async throws -> Int?
    let saveLastProcessedUpdateID: @Sendable (Int) async throws -> Void
    let flushSessions: @Sendable () async throws -> Void
    let logger: Logger
    let pollTimeoutSeconds: Int
    let retryDelayNanoseconds: UInt64
    private let taskState: PollingTaskState

    public init(
        getUpdates: @escaping @Sendable (Int?, Int) async throws -> [TelegramUpdate],
        handleIncomingText: @escaping @Sendable (Int64, String) async throws -> Void,
        loadLastProcessedUpdateID: @escaping @Sendable () async throws -> Int? = { nil },
        saveLastProcessedUpdateID: @escaping @Sendable (Int) async throws -> Void = { _ in },
        flushSessions: @escaping @Sendable () async throws -> Void = {},
        logger: Logger,
        pollTimeoutSeconds: Int = 30,
        retryDelayNanoseconds: UInt64 = 2_000_000_000
    ) {
        self.getUpdates = getUpdates
        self.handleIncomingText = handleIncomingText
        self.loadLastProcessedUpdateID = loadLastProcessedUpdateID
        self.saveLastProcessedUpdateID = saveLastProcessedUpdateID
        self.flushSessions = flushSessions
        self.logger = logger
        self.pollTimeoutSeconds = pollTimeoutSeconds
        self.retryDelayNanoseconds = retryDelayNanoseconds
        self.taskState = PollingTaskState()
    }

    public func didBootAsync(_ application: Application) async throws {
        let getUpdates = self.getUpdates
        let handleIncomingText = self.handleIncomingText
        let loadLastProcessedUpdateID = self.loadLastProcessedUpdateID
        let saveLastProcessedUpdateID = self.saveLastProcessedUpdateID
        let logger = self.logger
        let pollTimeoutSeconds = self.pollTimeoutSeconds
        let retryDelayNanoseconds = self.retryDelayNanoseconds

        let initialLastProcessedUpdateID: Int?
        do {
            initialLastProcessedUpdateID = try await loadLastProcessedUpdateID()
        } catch {
            logger.error(
                "Failed to load Telegram polling cursor",
                metadata: [
                    "error": .string(error.localizedDescription),
                ]
            )
            initialLastProcessedUpdateID = nil
        }

        let newTask = Task {
            var lastProcessedUpdateID = initialLastProcessedUpdateID
            var offset = initialLastProcessedUpdateID.map { $0 + 1 }

            while !Task.isCancelled {
                do {
                    let updates = try await getUpdates(offset, pollTimeoutSeconds)

                    for update in updates {
                        await handleUpdate(
                            update,
                            logger,
                            handleIncomingText,
                        )

                        let nextProcessedUpdateID: Int
                        if let lastProcessedUpdateID {
                            nextProcessedUpdateID = max(lastProcessedUpdateID, update.updateID)
                        } else {
                            nextProcessedUpdateID = update.updateID
                        }

                        if lastProcessedUpdateID != nextProcessedUpdateID {
                            lastProcessedUpdateID = nextProcessedUpdateID
                            offset = nextProcessedUpdateID + 1

                            do {
                                try await saveLastProcessedUpdateID(nextProcessedUpdateID)
                            } catch {
                                logger.error(
                                    "Failed to persist Telegram polling cursor",
                                    metadata: [
                                        "update_id": .stringConvertible(nextProcessedUpdateID),
                                        "error": .string(error.localizedDescription),
                                    ]
                                )
                            }
                        }
                    }
                } catch {
                    if Task.isCancelled {
                        break
                    }

                    logger.error(
                        "Telegram polling request failed",
                        metadata: [
                            "error": .string(error.localizedDescription),
                        ]
                    )

                    do {
                        try await Task.sleep(nanoseconds: retryDelayNanoseconds)
                    } catch {
                        break
                    }
                }
            }
        }

        let previousTask = await self.taskState.replace(with: newTask)
        previousTask?.cancel()
    }

    public func shutdownAsync(_ application: Application) async {
        if let task = await self.taskState.take() {
            task.cancel()
            _ = await task.result
        }

        do {
            try await self.flushSessions()
        } catch {
            self.logger.error(
                "Failed to flush session store on shutdown",
                metadata: [
                    "error": .string(error.localizedDescription),
                ]
            )
        }
    }
}

private actor PollingTaskState {
    private var task: Task<Void, Never>?

    func replace(with newTask: Task<Void, Never>) -> Task<Void, Never>? {
        let previous = self.task
        self.task = newTask
        return previous
    }

    func take() -> Task<Void, Never>? {
        let current = self.task
        self.task = nil
        return current
    }
}

private func handleUpdate(
    _ update: TelegramUpdate,
    _ logger: Logger,
    _ handleIncomingText: @Sendable (Int64, String) async throws -> Void,
) async {
    guard let message = update.message else { return }
    if message.from?.isBot == true { return }

    guard let text = message.text, !text.isEmpty else { return }

    do {
        try await handleIncomingText(message.chat.id, text)
    } catch {
        logger.error(
            "Failed to process polled Telegram message",
            metadata: [
                "update_id": .stringConvertible(update.updateID),
                "chat_id": .stringConvertible(message.chat.id),
                "error": .string(error.localizedDescription),
            ]
        )
    }
}
