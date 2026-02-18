import Foundation
import Vapor

public struct TelegramClient: Sendable {
    public var sendMessage: @Sendable (Int64, String) async throws -> TelegramSentMessage
    public var getUpdates: @Sendable (Int?, Int) async throws -> [TelegramUpdate]

    public init(
        sendMessage: @escaping @Sendable (Int64, String) async throws -> TelegramSentMessage,
        getUpdates: @escaping @Sendable (Int?, Int) async throws -> [TelegramUpdate]
    ) {
        self.sendMessage = sendMessage
        self.getUpdates = getUpdates
    }
}

extension TelegramClient {
    public static func live(client: any Client, botToken: String) -> Self {
        .init(
            sendMessage: { chatID, text in
                let endpoint = URI(string: "https://api.telegram.org/bot\(botToken)/sendMessage")
                let response = try await client.post(endpoint) { request in
                    try request.content.encode(
                        TelegramSendMessagePayload(chatID: chatID, text: text),
                        as: .json
                    )
                }

                let apiResponse = try response.content.decode(TelegramAPIResponse<TelegramSentMessage>.self)

                guard apiResponse.ok else {
                    throw TelegramClientError.api(
                        description: apiResponse.description ?? "Telegram API request failed.",
                        code: apiResponse.errorCode
                    )
                }

                guard let message = apiResponse.result else {
                    throw TelegramClientError.missingResult
                }

                return message
            },
            getUpdates: { offset, timeoutSeconds in
                let endpoint = URI(string: "https://api.telegram.org/bot\(botToken)/getUpdates")
                let response = try await client.post(endpoint) { request in
                    try request.content.encode(
                        TelegramGetUpdatesPayload(
                            offset: offset,
                            timeout: timeoutSeconds,
                            allowedUpdates: ["message"]
                        ),
                        as: .json
                    )
                }

                let apiResponse = try response.content.decode(TelegramAPIResponse<[TelegramUpdate]>.self)
                guard apiResponse.ok else {
                    throw TelegramClientError.api(
                        description: apiResponse.description ?? "Telegram API request failed.",
                        code: apiResponse.errorCode
                    )
                }

                return apiResponse.result ?? []
            }
        )
    }
}

