public struct TelegramSentMessage: Sendable {
    public let messageID: Int

    public init(messageID: Int) {
        self.messageID = messageID
    }
}

extension TelegramSentMessage: Decodable {
    enum CodingKeys: String, CodingKey {
        case messageID = "message_id"
    }
}

