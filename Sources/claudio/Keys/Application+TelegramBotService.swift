import Vapor
import TelegramBotService

extension Application {
    private struct TelegramBotServiceKey: StorageKey {
        typealias Value = TelegramBotService
    }

    var telegramBotService: TelegramBotService {
        get {
            guard let service = self.storage[TelegramBotServiceKey.self]
            else { fatalError("TelegramBotService not configured. Set app.telegramBotService in configure(_:).") }
            return service
        }
        set {
            self.storage[TelegramBotServiceKey.self] = newValue
        }
    }
}
