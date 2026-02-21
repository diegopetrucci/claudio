import Foundation

public struct SessionStore: Sendable {
    public var loadSession: @Sendable (Int64) async throws -> [SessionMessage]
    public var appendMessage: @Sendable (Int64, SessionMessageRole, String, Date) async throws -> Void
    public var loadLastProcessedUpdateID: @Sendable () async throws -> Int?
    public var saveLastProcessedUpdateID: @Sendable (Int) async throws -> Void
    public var flush: @Sendable () async throws -> Void

    public init(
        loadSession: @escaping @Sendable (Int64) async throws -> [SessionMessage],
        appendMessage: @escaping @Sendable (Int64, SessionMessageRole, String, Date) async throws -> Void,
        loadLastProcessedUpdateID: @escaping @Sendable () async throws -> Int?,
        saveLastProcessedUpdateID: @escaping @Sendable (Int) async throws -> Void,
        flush: @escaping @Sendable () async throws -> Void
    ) {
        self.loadSession = loadSession
        self.appendMessage = appendMessage
        self.loadLastProcessedUpdateID = loadLastProcessedUpdateID
        self.saveLastProcessedUpdateID = saveLastProcessedUpdateID
        self.flush = flush
    }
}

extension SessionStore {
    public static func live(
        baseDirectoryURL: URL,
        sessionsDirectoryName: String = ".sessions"
    ) throws -> Self {
        let sessionsDirectoryURL = baseDirectoryURL.appendingPathComponent(
            sessionsDirectoryName,
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: sessionsDirectoryURL,
            withIntermediateDirectories: true
        )
        
        return .init(
            loadSession: { chatID in
                let fileURL = sessionFileURL(
                    chatID: chatID,
                    sessionsDirectoryURL: sessionsDirectoryURL
                )
                let filePath = fileURL.path
                guard FileManager.default.fileExists(atPath: filePath)
                else { return [] }
                
                let data = try Data(contentsOf: fileURL)
                guard !data.isEmpty
                else { return [] }
                
                let lines = String(decoding: data, as: UTF8.self)
                    .split(whereSeparator: \.isNewline)
                
                var messages: [SessionMessage] = []
                messages.reserveCapacity(lines.count)
                
                for line in lines {
                    guard let lineData = String(line).data(using: .utf8)
                    else { continue }
                    
                    guard let message = try? jsonDecoder.decode(SessionMessage.self, from: lineData),
                        message.schemaVersion == 1
                    else { continue }
                    
                    messages.append(message)
                }
                
                return messages
            },
            appendMessage: { chatID, role, text, timestamp in
                try FileManager.default.createDirectory(
                    at: sessionsDirectoryURL,
                    withIntermediateDirectories: true
                )

                let fileURL = sessionFileURL(
                    chatID: chatID,
                    sessionsDirectoryURL: sessionsDirectoryURL
                )
                let filePath = fileURL.path
                if !FileManager.default.fileExists(atPath: filePath) {
                    let didCreateFile = FileManager.default.createFile(
                        atPath: filePath,
                        contents: nil
                    )
                    guard didCreateFile || FileManager.default.fileExists(atPath: filePath)
                    else { throw SessionStoreError.unableToCreateSessionFile(filePath) }
                }
                
                let message = SessionMessage(
                    role: role,
                    text: text,
                    timestamp: timestamp
                )
                let messageData = try jsonEncoder.encode(message)
                
                guard var jsonLine = String(data: messageData, encoding: .utf8)
                else { throw SessionStoreError.invalidUTF8 }
                jsonLine.append("\n")
                
                let fileHandle = try FileHandle(forWritingTo: fileURL)
                defer { try? fileHandle.close() }
                
                try fileHandle.seekToEnd()
                guard let lineData = jsonLine.data(using: .utf8)
                else { throw SessionStoreError.invalidUTF8 }
                try fileHandle.write(contentsOf: lineData)
            },
            loadLastProcessedUpdateID: {
                let fileURL = pollingCursorFileURL(sessionsDirectoryURL: sessionsDirectoryURL)
                let filePath = fileURL.path
                guard FileManager.default.fileExists(atPath: filePath)
                else { return nil }
                
                let data = try Data(contentsOf: fileURL)
                guard !data.isEmpty
                else { return nil }
                
                let cursor = try jsonDecoder.decode(PollingCursor.self, from: data)
                guard cursor.schemaVersion == 1
                else { return nil }
                
                return cursor.lastProcessedUpdateID
            },
            saveLastProcessedUpdateID: { updateID in
                try FileManager.default.createDirectory(
                    at: sessionsDirectoryURL,
                    withIntermediateDirectories: true
                )

                let cursor = PollingCursor(
                    schemaVersion: 1,
                    lastProcessedUpdateID: updateID
                )
                let data = try jsonEncoder.encode(cursor)
                try data.write(
                    to: pollingCursorFileURL(sessionsDirectoryURL: sessionsDirectoryURL),
                    options: [.atomic]
                )
            },
            flush: {
                guard FileManager.default.fileExists(atPath: sessionsDirectoryURL.path)
                else { return }

                let fileURLs = try FileManager.default.contentsOfDirectory(
                    at: sessionsDirectoryURL,
                    includingPropertiesForKeys: nil
                )

                for fileURL in fileURLs {
                    var isDirectory = ObjCBool(false)
                    let filePath = fileURL.path
                    guard FileManager.default.fileExists(
                        atPath: filePath,
                        isDirectory: &isDirectory
                    ),
                        !isDirectory.boolValue
                    else { continue }

                    let fileHandle = try FileHandle(forUpdating: fileURL)
                    defer { try? fileHandle.close() }
                    try fileHandle.synchronize()
                }
            }
        )
    }
}

private func sessionFileURL(
    chatID: Int64,
    sessionsDirectoryURL: URL
) -> URL {
    sessionsDirectoryURL.appendingPathComponent("\(chatID).jsonl")
}

private func pollingCursorFileURL(
    sessionsDirectoryURL: URL
) -> URL {
    sessionsDirectoryURL.appendingPathComponent("polling_cursor.json")
}
