struct TelegramAPIResponse<Result: Decodable & Sendable>: Decodable, Sendable {
    let ok: Bool
    let result: Result?
    let description: String?
    let errorCode: Int?
    
    enum CodingKeys: String, CodingKey {
        case ok
        case result
        case description
        case errorCode = "error_code"
    }
}
