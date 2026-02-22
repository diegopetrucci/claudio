public struct ToolSchema: Codable, Equatable, Sendable {
    public let type: String
    public let properties: [String: Property]
    public let required: [String]

    public init(
        type: String,
        properties: [String: Property],
        required: [String]
    ) {
        self.type = type
        self.properties = properties
        self.required = required
    }
}

extension ToolSchema {
    public struct Property: Codable, Equatable, Sendable {
        public let type: String
        public let description: String

        public init(
            type: String,
            description: String
        ) {
            self.type = type
            self.description = description
        }
    }
}
