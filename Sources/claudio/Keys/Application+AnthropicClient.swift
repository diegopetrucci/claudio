import Vapor
import AnthropicClient

extension Application {
    private struct AnthropicClientKey: StorageKey {
        typealias Value = AnthropicClient
    }

    var anthropicClient: AnthropicClient {
        get {
            guard let client = self.storage[AnthropicClientKey.self] else {
                fatalError("AnthropicClient not configured. Set app.anthropicClient in configure(_:).")
            }
            return client
        }
        set {
            self.storage[AnthropicClientKey.self] = newValue
        }
    }
}

