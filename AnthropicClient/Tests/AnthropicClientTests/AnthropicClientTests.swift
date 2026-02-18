@testable import AnthropicClient
import Foundation
import SwiftAnthropic
import Testing

@Suite("AnthropicClient Tests")
struct AnthropicClientTests {
    @Test("generateText builds message request and returns text response")
    func generateTextBuildsRequest() async throws {
        let recorder = AnthropicRequestRecorder()
        let client = AnthropicClient.live(
            model: .sonnet,
            maxTokens: 256,
            systemPrompt: "You are concise.",
            createMessage: { parameter in
                await recorder.record(Self.captureRequest(from: parameter))
                return try Self.decodeMessageResponse(
                    #"""
                    {
                      "id":"msg_1",
                      "type":"message",
                      "model":"claude-3-7-sonnet-latest",
                      "role":"assistant",
                      "content":[{"type":"text","text":"Hello from Claude"}],
                      "stop_reason":"end_turn",
                      "stop_sequence":null,
                      "usage":{"input_tokens":10,"output_tokens":4}
                    }
                    """#
                )
            }
        )

        let text = try await client.generateText("hello")
        #expect(text == "Hello from Claude")

        let request = await recorder.request
        #expect(request?.model == AnthropicModel.sonnet.apiValue)
        #expect(request?.maxTokens == 256)
        #expect(request?.systemPrompt == "You are concise.")
        #expect(request?.messages.count == 1)
        #expect(request?.messages.first?.role == "user")
        #expect(request?.messages.first?.text == "hello")
    }

    @Test("generateText concatenates all text blocks")
    func generateTextConcatsTextBlocks() async throws {
        let client = AnthropicClient.live(
            model: .sonnet,
            maxTokens: 256,
            createMessage: { _ in
                try Self.decodeMessageResponse(
                    #"""
                    {
                      "id":"msg_1",
                      "type":"message",
                      "model":"claude-3-7-sonnet-latest",
                      "role":"assistant",
                      "content":[
                        {"type":"text","text":"Hello"},
                        {"type":"text","text":" world"}
                      ],
                      "stop_reason":"end_turn",
                      "stop_sequence":null,
                      "usage":{"input_tokens":10,"output_tokens":4}
                    }
                    """#
                )
            }
        )

        let text = try await client.generateText("hello")
        #expect(text == "Hello world")
    }

    @Test("generateText throws when response contains no text blocks")
    func generateTextThrowsWhenNoText() async throws {
        let client = AnthropicClient.live(
            model: .sonnet,
            maxTokens: 256,
            createMessage: { _ in
                try Self.decodeMessageResponse(
                    #"""
                    {
                      "id":"msg_1",
                      "type":"message",
                      "model":"claude-3-7-sonnet-latest",
                      "role":"assistant",
                      "content":[],
                      "stop_reason":"end_turn",
                      "stop_sequence":null,
                      "usage":{"input_tokens":10,"output_tokens":4}
                    }
                    """#
                )
            }
        )

        do {
            _ = try await client.generateText("hello")
            Issue.record("Expected AnthropicClientError.missingTextContent, but call succeeded.")
        } catch let error as AnthropicClientError {
            switch error {
            case .missingTextContent:
                break
            }
        }
    }

    private static func decodeMessageResponse(_ json: String) throws -> MessageResponse {
        let data = Data(json.utf8)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(MessageResponse.self, from: data)
    }

    private static func captureRequest(from parameter: MessageParameter) -> CapturedAnthropicRequest {
        let systemPrompt: String?
        if case let .text(systemText)? = parameter.system {
            systemPrompt = systemText
        } else {
            systemPrompt = nil
        }

        let messages = parameter.messages.map { message in
            let text: String?
            if case let .text(value) = message.content {
                text = value
            } else {
                text = nil
            }
            return CapturedAnthropicMessage(role: message.role, text: text)
        }

        return CapturedAnthropicRequest(
            model: parameter.model,
            maxTokens: parameter.maxTokens,
            systemPrompt: systemPrompt,
            messages: messages
        )
    }
}

private actor AnthropicRequestRecorder {
    private(set) var request: CapturedAnthropicRequest?

    func record(_ request: CapturedAnthropicRequest) {
        self.request = request
    }
}

private struct CapturedAnthropicRequest: Sendable {
    let model: String
    let maxTokens: Int
    let systemPrompt: String?
    let messages: [CapturedAnthropicMessage]
}

private struct CapturedAnthropicMessage: Sendable {
    let role: String
    let text: String?
}
