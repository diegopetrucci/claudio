import Vapor

public struct TelegramUpdate: Content, Sendable {
    public let updateID: Int
    public let message: TelegramMessage?

    public init(updateID: Int, message: TelegramMessage?) {
        self.updateID = updateID
        self.message = message
    }

    enum CodingKeys: String, CodingKey {
        case updateID = "update_id"
        case message
    }
}

