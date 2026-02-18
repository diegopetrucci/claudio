import Vapor

extension Application {
    private struct TelegramPollingTaskKey: StorageKey {
        typealias Value = Task<Void, Never>
    }

    var telegramPollingTask: Task<Void, Never>? {
        get {
            self.storage[TelegramPollingTaskKey.self]
        }
        set {
            self.storage[TelegramPollingTaskKey.self] = newValue
        }
    }
}

