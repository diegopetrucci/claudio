import Vapor
import SessionStore

extension Application {
    private struct SessionStoreKey: StorageKey {
        typealias Value = SessionStore
    }

    var sessionStore: SessionStore {
        get {
            guard let store = self.storage[SessionStoreKey.self]
            else { fatalError("SessionStore not configured. Set app.sessionStore in configure(_:).") }
            return store
        }
        set {
            self.storage[SessionStoreKey.self] = newValue
        }
    }
}
