@testable import AnthropicClient
import Foundation
import SwiftAnthropic
import Testing

@Suite("AnthropicClient Tests")
struct AnthropicClientTests {
    @Test("respond builds message request and returns text response")
    func respondBuildsRequest() async throws {
        let recorder = AnthropicRequestRecorder()
        let client = AnthropicClient.live(
            apiKey: "test-key",
            model: .sonnet,
            maxTokens: 256,
            loadSystemPrompt: {
                "You are concise."
            },
            createMessageOverride: { parameter in
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

        let incomingMessage = try await client.respond(.init(text: "hello"))
        #expect(incomingMessage.text == "Hello from Claude")

        let request = await recorder.request
        #expect(request?.model == AnthropicModel.sonnet.apiValue)
        #expect(request?.maxTokens == 256)
        #expect(request?.systemPrompt == "You are concise.")
        #expect(request?.messages.count == 1)
        #expect(request?.messages.first?.role == "user")
        #expect(request?.messages.first?.text == "hello")
    }

    @Test("respond concatenates all text blocks")
    func respondConcatsTextBlocks() async throws {
        let client = AnthropicClient.live(
            apiKey: "test-key",
            model: .sonnet,
            maxTokens: 256,
            loadSystemPrompt: {
                "You are concise."
            },
            createMessageOverride: { _ in
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

        let incomingMessage = try await client.respond(.init(text: "hello"))
        #expect(incomingMessage.text == "Hello world")
    }

    @Test("respond throws when response contains no text blocks")
    func respondThrowsWhenNoText() async throws {
        let client = AnthropicClient.live(
            apiKey: "test-key",
            model: .sonnet,
            maxTokens: 256,
            loadSystemPrompt: {
                "You are concise."
            },
            createMessageOverride: { _ in
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
            _ = try await client.respond(.init(text: "hello"))
            Issue.record("Expected AnthropicClientError.missingTextContent, but call succeeded.")
        } catch let error as AnthropicClientError {
            switch error {
            case .missingTextContent:
                break
            default:
                Issue.record("Expected AnthropicClientError.missingTextContent, but got \(error).")
            }
        }
    }

    @Test("respond executes tool call and sends tool_result message")
    func respondWithToolsRoundTrip() async throws {
        let payloadRecorder = AnthropicPayloadRecorder()
        let responses = MessageResponseSequence(
            responses: [
                #"""
                    {
                      "id":"msg_1",
                      "type":"message",
                      "model":"claude-3-7-sonnet-latest",
                      "role":"assistant",
                      "content":[
                        {
                          "type":"tool_use",
                          "id":"toolu_1",
                          "name":"run_command",
                          "input":{"command":"printf 'hello'"}
                        }
                      ],
                      "stop_reason":"tool_use",
                      "stop_sequence":null,
                      "usage":{"input_tokens":10,"output_tokens":4}
                    }
                    """#,
                #"""
                    {
                      "id":"msg_2",
                      "type":"message",
                      "model":"claude-3-7-sonnet-latest",
                      "role":"assistant",
                      "content":[{"type":"text","text":"Tool says hello"}],
                      "stop_reason":"end_turn",
                      "stop_sequence":null,
                      "usage":{"input_tokens":20,"output_tokens":6}
                    }
                    """#,
            ]
        )

        let client = AnthropicClient.live(
            apiKey: "test-key",
            model: .sonnet,
            maxTokens: 256,
            loadSystemPrompt: {
                "You are concise."
            },
            createMessageOverride: { parameter in
                await payloadRecorder.record(Self.encodeMessageParameter(parameter))
                return try Self.decodeMessageResponse(try await responses.next())
            }
        )

        let incomingMessage = try await client.respond(.init(text: "hello"))

        #expect(incomingMessage.text == "Tool says hello")
        let payloads = await payloadRecorder.all()
        #expect(payloads.count == 2)
        #expect(payloads[0].contains("\"tools\""))
        #expect(payloads[1].contains("\"tool_result\""))
        #expect(payloads[1].contains("\"tool_use_id\":\"toolu_1\""))
        #expect(payloads[1].contains("\"content\":\"hello\""))
    }

    @Test("respond uses injected witness implementation")
    func respondUsesInjectedWitnessImplementation() async throws {
        let client = AnthropicClient(
            respond: { outgoingMessage in
                .init(text: "reply for \(outgoingMessage.text)")
            }
        )

        let incomingMessage = try await client.respond(.init(text: "hello"))

        #expect(incomingMessage.text == "reply for hello")
    }

    @Test("ensureSystemPromptFileExists writes default content when missing")
    func ensureSystemPromptFileExistsWritesDefaultContentWhenMissing() throws {
        let tempDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectoryURL) }

        let promptFileURL = tempDirectoryURL.appendingPathComponent("SOUL.md")
        let client = AnthropicClient.live(
            apiKey: "test-key",
            model: .sonnet,
            maxTokens: 256,
            loadSystemPrompt: {
                "You are concise."
            }
        )
        try client.ensureSystemPromptFileExists(promptFileURL.path)

        let prompt = try String(contentsOf: promptFileURL, encoding: .utf8)
        #expect(prompt == AnthropicClient.defaultSystemPrompt)
    }

    @Test("ensureSystemPromptFileExists does not overwrite existing file")
    func ensureSystemPromptFileExistsDoesNotOverwriteExistingFile() throws {
        let tempDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectoryURL) }

        let promptFileURL = tempDirectoryURL.appendingPathComponent("SOUL.md")
        try "Custom prompt".write(to: promptFileURL, atomically: true, encoding: .utf8)
        let client = AnthropicClient.live(
            apiKey: "test-key",
            model: .sonnet,
            maxTokens: 256,
            loadSystemPrompt: {
                "You are concise."
            }
        )
        try client.ensureSystemPromptFileExists(promptFileURL.path)

        let prompt = try String(contentsOf: promptFileURL, encoding: .utf8)
        #expect(prompt == "Custom prompt")
    }

    private static func decodeMessageResponse(_ json: String) throws -> MessageResponse {
        let data = Data(json.utf8)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(MessageResponse.self, from: data)
    }

    private static func encodeMessageParameter(_ parameter: MessageParameter) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(parameter)
        else { return "" }
        return String(decoding: data, as: UTF8.self)
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

private actor AnthropicPayloadRecorder {
    private var payloads: [String] = []

    func record(_ payload: String) {
        self.payloads.append(payload)
    }

    func all() -> [String] {
        self.payloads
    }
}

private actor MessageResponseSequence {
    private var responses: [String]

    init(responses: [String]) {
        self.responses = responses
    }

    func next() throws -> String {
        guard !self.responses.isEmpty
        else { throw MessageResponseSequenceError.outOfResponses }
        return self.responses.removeFirst()
    }
}

private enum MessageResponseSequenceError: Error {
    case outOfResponses
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
