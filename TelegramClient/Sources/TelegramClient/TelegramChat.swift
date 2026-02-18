import Vapor

public struct TelegramChat: Content, Sendable {
    public let id: Int64

    public init(id: Int64) {
        self.id = id
    }
}

