import Vapor

struct TelegramGetUpdatesPayload: Content, Sendable {
    let offset: Int?
    let timeout: Int
    let allowedUpdates: [String]?

    enum CodingKeys: String, CodingKey {
        case offset
        case timeout
        case allowedUpdates = "allowed_updates"
    }
}

