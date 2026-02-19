struct PollingCursor: Codable, Sendable {
    let schemaVersion: Int
    let lastProcessedUpdateID: Int
}
