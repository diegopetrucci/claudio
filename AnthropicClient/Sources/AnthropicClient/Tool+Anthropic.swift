@preconcurrency import SwiftAnthropic
import ToolExecutor

extension Tool {
    var toAnthropicTool: MessageParameter.Tool {
        get throws {
            var properties: [String: JSONSchema.Property] = [:]
            properties.reserveCapacity(schema.properties.count)

            for (propertyName, property) in schema.properties {
                properties[propertyName] = .init(
                    type: try Self.convertToAnthropicSchemaType(
                        property.type,
                        context: "\(name).\(propertyName)"
                    ),
                    description: property.description
                )
            }

            return MessageParameter.Tool.function(
                name: name,
                description: description,
                inputSchema: JSONSchema(
                    type: try Self.convertToAnthropicSchemaType(
                        schema.type,
                        context: "\(name) schema"
                    ),
                    properties: properties,
                    required: schema.required
                )
            )
        }
    }

    private static func convertToAnthropicSchemaType(
        _ type: String,
        context: String
    ) throws -> JSONSchema.JSONType {
        switch type.lowercased() {
        case "integer":
            return .integer
        case "string":
            return .string
        case "boolean":
            return .boolean
        case "array":
            return .array
        case "object":
            return .object
        case "number":
            return .number
        case "null":
            return .null
        default:
            throw AnthropicClientError.unsupportedToolSchemaType(type: type, context: context)
        }
    }
}
