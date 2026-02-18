import Vapor

extension Application {
    private struct TelegramWebhookSecretTokenKey: StorageKey {
        typealias Value = String
    }

    var telegramWebhookSecretToken: String? {
        get {
            self.storage[TelegramWebhookSecretTokenKey.self]
        }
        
        set {
            self.storage[TelegramWebhookSecretTokenKey.self] = newValue
        }
    }
}

