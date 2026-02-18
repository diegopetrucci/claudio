struct TelegramSentMessage: Sendable {
    let messageID: Int
}

extension TelegramSentMessage: Decodable {
    enum CodingKeys: String, CodingKey {
        case messageID = "message_id"
    }
}
