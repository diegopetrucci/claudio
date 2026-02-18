import Vapor

public struct TelegramMessage: Content, Sendable {
    public let messageID: Int
    public let from: TelegramUser?
    public let chat: TelegramChat
    public let text: String?

    public init(
        messageID: Int,
        from: TelegramUser?,
        chat: TelegramChat,
        text: String?
    ) {
        self.messageID = messageID
        self.from = from
        self.chat = chat
        self.text = text
    }

    enum CodingKeys: String, CodingKey {
        case messageID = "message_id"
        case from
        case chat
        case text
    }
}

