import Vapor

struct TelegramUpdate: Content, Sendable {
    let updateID: Int
    let message: TelegramMessage?

    enum CodingKeys: String, CodingKey {
        case updateID = "update_id"
        case message
    }
}

