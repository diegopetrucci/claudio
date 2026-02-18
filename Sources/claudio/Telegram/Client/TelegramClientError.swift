import Foundation

enum TelegramClientError: Error, Sendable {
    case api(description: String, code: Int?)
    case missingResult
}

extension TelegramClientError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case let .api(description, code):
            if let code {
                return "Telegram API error \(code): \(description)"
            } else {
                return "Telegram API error: \(description)"
            }
        case .missingResult:
            return "Telegram API returned no result payload."
        }
    }
}
