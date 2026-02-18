import Vapor

public struct TelegramUser: Content, Sendable {
    public let id: Int64
    public let isBot: Bool

    public init(id: Int64, isBot: Bool) {
        self.id = id
        self.isBot = isBot
    }

    enum CodingKeys: String, CodingKey {
        case id
        case isBot = "is_bot"
    }
}

