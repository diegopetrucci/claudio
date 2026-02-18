@testable import claudio
import Foundation
import Logging
import NIOCore
import NIOPosix
import Testing
import Vapor

@Suite("TelegramClient Tests")
struct TelegramClientTests {
    @Test("live sendMessage encodes request and decodes successful response")
    func liveSendMessageSuccess() async throws {
        try await Self.withEventLoop { eventLoop in
            let recorder = RequestRecorder()
            let httpClient = StubClient(eventLoop: eventLoop) { request in
                recorder.append(request)
                return eventLoop.makeSucceededFuture(
                    Self.makeJSONResponse(#"{"ok":true,"result":{"message_id":42}}"#)
                )
            }

            let telegramClient = TelegramClient.live(client: httpClient, botToken: "bot-token")
            let sentMessage = try await telegramClient.sendMessage(123_456_789, "hello")

            #expect(sentMessage.messageID == 42)
            let request = try #require(recorder.firstRequest)
            #expect(request.method == .POST)
            #expect(request.url.string == "https://api.telegram.org/botbot-token/sendMessage")

            let captured = request
            let payload = try captured.content.decode(TelegramSendMessagePayload.self)
            #expect(payload.chatID == 123_456_789)
            #expect(payload.text == "hello")
        }
    }

    @Test("live sendMessage maps Telegram API error payload")
    func liveSendMessageAPIError() async throws {
        try await Self.withEventLoop { eventLoop in
            let httpClient = StubClient(eventLoop: eventLoop) { _ in
                eventLoop.makeSucceededFuture(
                    Self.makeJSONResponse(#"{"ok":false,"description":"Too Many Requests","error_code":429}"#)
                )
            }

            let telegramClient = TelegramClient.live(client: httpClient, botToken: "bot-token")

            do {
                _ = try await telegramClient.sendMessage(1, "hello")
                Issue.record("Expected TelegramClientError.api, but call succeeded.")
            } catch let error as TelegramClientError {
                switch error {
                case let .api(description, code):
                    #expect(description == "Too Many Requests")
                    #expect(code == 429)
                default:
                    Issue.record("Expected .api error, got \(error).")
                }
            }
        }
    }

    @Test("live sendMessage throws missingResult when ok=true and result is absent")
    func liveSendMessageMissingResult() async throws {
        try await Self.withEventLoop { eventLoop in
            let httpClient = StubClient(eventLoop: eventLoop) { _ in
                eventLoop.makeSucceededFuture(Self.makeJSONResponse(#"{"ok":true}"#))
            }

            let telegramClient = TelegramClient.live(client: httpClient, botToken: "bot-token")

            do {
                _ = try await telegramClient.sendMessage(1, "hello")
                Issue.record("Expected TelegramClientError.missingResult, but call succeeded.")
            } catch let error as TelegramClientError {
                switch error {
                case .missingResult:
                    break
                default:
                    Issue.record("Expected .missingResult error, got \(error).")
                }
            }
        }
    }

    @Test("live getUpdates encodes request and decodes updates")
    func liveGetUpdatesSuccess() async throws {
        try await Self.withEventLoop { eventLoop in
            let recorder = RequestRecorder()
            let httpClient = StubClient(eventLoop: eventLoop) { request in
                recorder.append(request)
                return eventLoop.makeSucceededFuture(
                    Self.makeJSONResponse(#"{"ok":true,"result":[{"update_id":123}]}"#)
                )
            }

            let telegramClient = TelegramClient.live(client: httpClient, botToken: "bot-token")
            let updates = try await telegramClient.getUpdates(120, 30)

            #expect(updates.count == 1)
            #expect(updates[0].updateID == 123)

            let request = try #require(recorder.firstRequest)
            #expect(request.method == .POST)
            #expect(request.url.string == "https://api.telegram.org/botbot-token/getUpdates")

            let captured = request
            let payload = try captured.content.decode(TelegramGetUpdatesPayload.self)
            #expect(payload.offset == 120)
            #expect(payload.timeout == 30)
            #expect(payload.allowedUpdates == ["message"])
        }
    }

    @Test("live getUpdates maps Telegram API error payload")
    func liveGetUpdatesAPIError() async throws {
        try await Self.withEventLoop { eventLoop in
            let httpClient = StubClient(eventLoop: eventLoop) { _ in
                eventLoop.makeSucceededFuture(
                    Self.makeJSONResponse(#"{"ok":false,"description":"Unauthorized","error_code":401}"#)
                )
            }

            let telegramClient = TelegramClient.live(client: httpClient, botToken: "bot-token")

            do {
                _ = try await telegramClient.getUpdates(nil, 30)
                Issue.record("Expected TelegramClientError.api, but call succeeded.")
            } catch let error as TelegramClientError {
                switch error {
                case let .api(description, code):
                    #expect(description == "Unauthorized")
                    #expect(code == 401)
                default:
                    Issue.record("Expected .api error, got \(error).")
                }
            }
        }
    }

    private static func makeJSONResponse(_ json: String) -> ClientResponse {
        var headers = HTTPHeaders()
        headers.contentType = .json
        var body = ByteBufferAllocator().buffer(capacity: json.utf8.count)
        body.writeString(json)
        return ClientResponse(status: .ok, headers: headers, body: body)
    }

    private static func withEventLoop(
        _ operation: @Sendable (any EventLoop) async throws -> Void
    ) async throws {
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        do {
            try await operation(eventLoopGroup.next())
            try await eventLoopGroup.shutdownGracefully()
        } catch {
            try? await eventLoopGroup.shutdownGracefully()
            throw error
        }
    }
}

private struct StubClient: Client {
    let eventLoop: any EventLoop
    let byteBufferAllocator: ByteBufferAllocator
    private let sendHandler: @Sendable (ClientRequest) -> EventLoopFuture<ClientResponse>

    init(
        eventLoop: any EventLoop,
        byteBufferAllocator: ByteBufferAllocator = .init(),
        sendHandler: @escaping @Sendable (ClientRequest) -> EventLoopFuture<ClientResponse>
    ) {
        self.eventLoop = eventLoop
        self.byteBufferAllocator = byteBufferAllocator
        self.sendHandler = sendHandler
    }

    func delegating(to eventLoop: any EventLoop) -> any Client {
        Self(eventLoop: eventLoop, byteBufferAllocator: self.byteBufferAllocator, sendHandler: self.sendHandler)
    }

    func logging(to logger: Logger) -> any Client {
        self
    }

    func allocating(to byteBufferAllocator: ByteBufferAllocator) -> any Client {
        Self(eventLoop: self.eventLoop, byteBufferAllocator: byteBufferAllocator, sendHandler: self.sendHandler)
    }

    func send(_ request: ClientRequest) -> EventLoopFuture<ClientResponse> {
        self.sendHandler(request)
    }
}

private final class RequestRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var requests: [ClientRequest] = []

    var firstRequest: ClientRequest? {
        self.lock.lock()
        defer { self.lock.unlock() }
        return self.requests.first
    }

    func append(_ request: ClientRequest) {
        self.lock.lock()
        defer { self.lock.unlock() }
        self.requests.append(request)
    }
}
