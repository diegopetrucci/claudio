import Vapor

struct TelegramPollingLifecycleHandler: LifecycleHandler {
    let pollTimeoutSeconds: Int
    let retryDelayNanoseconds: UInt64

    init(
        pollTimeoutSeconds: Int = 30,
        retryDelayNanoseconds: UInt64 = 2_000_000_000
    ) {
        self.pollTimeoutSeconds = pollTimeoutSeconds
        self.retryDelayNanoseconds = retryDelayNanoseconds
    }

    func didBootAsync(_ application: Application) async throws {
        let getUpdates = application.telegramClient.getUpdates
        let handleIncomingText = application.telegramBotService.handleIncomingText
        let logger = application.logger
        let pollTimeoutSeconds = self.pollTimeoutSeconds
        let retryDelayNanoseconds = self.retryDelayNanoseconds

        application.telegramPollingTask = Task {
            var offset: Int?

            while !Task.isCancelled {
                do {
                    let updates = try await getUpdates(offset, pollTimeoutSeconds)
                    if let maxUpdateID = updates.map(\.updateID).max() {
                        offset = maxUpdateID + 1
                    }

                    for update in updates {
                        try await handleUpdate(
                            update,
                            logger,
                            handleIncomingText,
                        )
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
    }

    func shutdownAsync(_ application: Application) async {
        guard let task = application.telegramPollingTask else {
            return
        }

        task.cancel()
        _ = await task.result
        application.telegramPollingTask = nil
    }
}

private func handleUpdate(
    _ update: TelegramUpdate,
    _ logger: Logger,
    _ handleIncomingText: @Sendable (Int64, String) async throws -> Void,
) async throws {
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
