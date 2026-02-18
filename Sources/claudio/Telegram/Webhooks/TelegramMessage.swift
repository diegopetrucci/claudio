import Vapor

struct TelegramMessage: Content, Sendable {
    let messageID: Int
    let from: TelegramUser?
    let chat: TelegramChat
    let text: String?

    enum CodingKeys: String, CodingKey {
        case messageID = "message_id"
        case from
        case chat
        case text
    }
}

