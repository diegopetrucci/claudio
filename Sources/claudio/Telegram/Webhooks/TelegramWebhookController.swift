import Vapor

struct TelegramWebhookController: RouteCollection {
    private let secretHeaderName = "X-Telegram-Bot-Api-Secret-Token"

    func boot(routes: any RoutesBuilder) throws {
        let telegram = routes.grouped("telegram")
        telegram.post("webhook", use: self.handle)
    }

    func handle(_ req: Request) async throws -> HTTPStatus {
        try self.validateSecretTokenHeader(on: req)

        let update = try req.content.decode(TelegramUpdate.self)
        guard let message = update.message else {
            return .ok
        }

        if message.from?.isBot == true {
            return .ok
        }

        guard let text = message.text, !text.isEmpty else {
            return .ok
        }

        do {
            _ = try await req.application.telegramClient.sendMessage(message.chat.id, "Echo: \(text)")
        } catch {
            req.logger.error(
                "Failed to send Telegram message",
                metadata: [
                    "update_id": .stringConvertible(update.updateID),
                    "chat_id": .stringConvertible(message.chat.id),
                    "error": .string(error.localizedDescription),
                ]
            )
        }

        return .ok
    }

    private func validateSecretTokenHeader(on req: Request) throws {
        guard let expectedToken = req.application.telegramWebhookSecretToken
        else { return }

        guard req.headers.first(name: self.secretHeaderName) == expectedToken else {
            throw Abort(.unauthorized, reason: "Invalid Telegram webhook secret token.")
        }
    }
}

