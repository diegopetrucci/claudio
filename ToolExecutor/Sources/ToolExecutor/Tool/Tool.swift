import Foundation

public struct Tool: Codable, Equatable, Sendable {
    public let name: String
    public let description: String
    public let schema: ToolSchema

    public init(
        name: String,
        description: String,
        schema: ToolSchema
    ) {
        self.name = name
        self.description = description
        self.schema = schema
    }
}
