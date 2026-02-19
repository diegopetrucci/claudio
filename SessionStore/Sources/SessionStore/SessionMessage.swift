import Foundation

public struct SessionMessage: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let role: SessionMessageRole
    public let text: String
    public let timestamp: Date

    public init(
        role: SessionMessageRole,
        text: String,
        timestamp: Date = Date()
    ) {
        self.schemaVersion = 1
        self.role = role
        self.text = text
        self.timestamp = timestamp
    }
}
