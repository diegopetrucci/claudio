import Vapor

struct TelegramUser: Content, Sendable {
    let id: Int64
    let isBot: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case isBot = "is_bot"
    }
}

