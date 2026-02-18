import Vapor

struct TelegramSendMessagePayload: Content, Sendable {
    let chatID: Int64
    let text: String
    
    enum CodingKeys: String, CodingKey {
        case chatID = "chat_id"
        case text
    }
}
