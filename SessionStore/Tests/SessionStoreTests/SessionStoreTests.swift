import Foundation
import Testing
@testable import SessionStore

@Suite("SessionStore Tests")
struct SessionStoreTests {
    @Test("append and load round trip")
    func appendAndLoadRoundTrip() async throws {
        let baseDirectoryURL = try makeTemporaryDirectoryURL()
        defer { try? FileManager.default.removeItem(at: baseDirectoryURL) }

        let sessionStore = try SessionStore.live(baseDirectoryURL: baseDirectoryURL)
        let userTimestamp = Date(timeIntervalSince1970: 100)
        let assistantTimestamp = Date(timeIntervalSince1970: 200)

        try await sessionStore.appendMessage(101, .user, "hello", userTimestamp)
        try await sessionStore.appendMessage(101, .assistant, "hi", assistantTimestamp)

        let messages = try await sessionStore.loadSession(101)
        #expect(
            messages == [
                SessionMessage(role: .user, text: "hello", timestamp: userTimestamp),
                SessionMessage(role: .assistant, text: "hi", timestamp: assistantTimestamp),
            ]
        )
    }

    @Test("loadSession ignores malformed lines")
    func loadSessionIgnoresMalformedLines() async throws {
        let baseDirectoryURL = try makeTemporaryDirectoryURL()
        defer { try? FileManager.default.removeItem(at: baseDirectoryURL) }

        let sessionStore = try SessionStore.live(baseDirectoryURL: baseDirectoryURL)
        let sessionsDirectoryURL = baseDirectoryURL.appendingPathComponent(".sessions", isDirectory: true)
        let sessionFileURL = sessionsDirectoryURL.appendingPathComponent("101.jsonl")

        let validMessage = SessionMessage(
            role: .assistant,
            text: "valid",
            timestamp: Date(timeIntervalSince1970: 300)
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let validLine = String(
            data: try encoder.encode(validMessage),
            encoding: .utf8
        )!

        let invalidSchemaLine = """
        {"schemaVersion":2,"role":"user","text":"ignored","timestamp":"1970-01-01T00:00:00Z"}
        """
        let malformedLine = "{not-json"
        let fileContents = "\(malformedLine)\n\(validLine)\n\(invalidSchemaLine)\n"
        try fileContents.write(to: sessionFileURL, atomically: true, encoding: .utf8)

        let messages = try await sessionStore.loadSession(101)
        #expect(messages == [validMessage])
    }

    @Test("cursor save and load round trip")
    func cursorSaveAndLoadRoundTrip() async throws {
        let baseDirectoryURL = try makeTemporaryDirectoryURL()
        defer { try? FileManager.default.removeItem(at: baseDirectoryURL) }

        let sessionStore = try SessionStore.live(baseDirectoryURL: baseDirectoryURL)
        #expect(try await sessionStore.loadLastProcessedUpdateID() == nil)

        try await sessionStore.saveLastProcessedUpdateID(77)
        #expect(try await sessionStore.loadLastProcessedUpdateID() == 77)
    }

    @Test("cursor save recreates sessions directory if removed")
    func cursorSaveRecreatesSessionsDirectoryIfRemoved() async throws {
        let baseDirectoryURL = try makeTemporaryDirectoryURL()
        defer { try? FileManager.default.removeItem(at: baseDirectoryURL) }

        let sessionStore = try SessionStore.live(baseDirectoryURL: baseDirectoryURL)
        let sessionsDirectoryURL = baseDirectoryURL.appendingPathComponent(".sessions", isDirectory: true)
        try FileManager.default.removeItem(at: sessionsDirectoryURL)

        try await sessionStore.saveLastProcessedUpdateID(77)
        #expect(try await sessionStore.loadLastProcessedUpdateID() == 77)
    }

    @Test("flush succeeds")
    func flushSucceeds() async throws {
        let baseDirectoryURL = try makeTemporaryDirectoryURL()
        defer { try? FileManager.default.removeItem(at: baseDirectoryURL) }

        let sessionStore = try SessionStore.live(baseDirectoryURL: baseDirectoryURL)
        try await sessionStore.appendMessage(
            101,
            .user,
            "hello",
            Date(timeIntervalSince1970: 100)
        )
        try await sessionStore.saveLastProcessedUpdateID(3)

        try await sessionStore.flush()
    }

    @Test("append recreates sessions directory if removed")
    func appendRecreatesSessionsDirectoryIfRemoved() async throws {
        let baseDirectoryURL = try makeTemporaryDirectoryURL()
        defer { try? FileManager.default.removeItem(at: baseDirectoryURL) }

        let sessionStore = try SessionStore.live(baseDirectoryURL: baseDirectoryURL)
        let sessionsDirectoryURL = baseDirectoryURL.appendingPathComponent(".sessions", isDirectory: true)
        try FileManager.default.removeItem(at: sessionsDirectoryURL)

        try await sessionStore.appendMessage(
            101,
            .user,
            "hello",
            Date(timeIntervalSince1970: 100)
        )

        let messages = try await sessionStore.loadSession(101)
        #expect(
            messages == [
                SessionMessage(
                    role: .user,
                    text: "hello",
                    timestamp: Date(timeIntervalSince1970: 100)
                ),
            ]
        )
    }

    @Test("append and load work when base directory path contains spaces")
    func appendAndLoadWithSpaceInBaseDirectoryPath() async throws {
        let baseDirectoryURL = try makeTemporaryDirectoryURL(prefix: "Session Store Tests")
        defer { try? FileManager.default.removeItem(at: baseDirectoryURL) }

        let sessionStore = try SessionStore.live(baseDirectoryURL: baseDirectoryURL)
        let timestamp = Date(timeIntervalSince1970: 100)

        try await sessionStore.appendMessage(101, .user, "hello", timestamp)

        let messages = try await sessionStore.loadSession(101)
        #expect(
            messages == [
                SessionMessage(
                    role: .user,
                    text: "hello",
                    timestamp: timestamp
                ),
            ]
        )
    }
}

private func makeTemporaryDirectoryURL(
    prefix: String = "SessionStoreTests"
) throws -> URL {
    let directoryURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("\(prefix)-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    return directoryURL
}
