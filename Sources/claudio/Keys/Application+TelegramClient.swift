import Vapor
import TelegramClient

extension Application {
    private struct TelegramClientKey: StorageKey {
        typealias Value = TelegramClient
    }

    var telegramClient: TelegramClient {
        get {
            guard let client = self.storage[TelegramClientKey.self]
            else { fatalError("TelegramClient not configured. Set app.telegramClient in configure(_:).") }
            return client
        }
        set {
            self.storage[TelegramClientKey.self] = newValue
        }
    }
}
