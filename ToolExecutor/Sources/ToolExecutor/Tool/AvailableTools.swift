public enum AvailableTools: String, CaseIterable, Sendable {
    case runCommand = "run_command"
    case readFile = "read_file"
    case writeFile = "write_file"
    case webSearch = "web_search"
}

extension AvailableTools {
    public var name: String {
        self.rawValue
    }

    public var description: String {
        switch self {
        case .readFile:
            return "Read the contents of a file."
        case .writeFile:
            return "Write content to a file."
        case .runCommand:
            return "Execute a shell command and return its output."
        case .webSearch:
            return "Perform a web search and return the results."
        }
    }

    public var schema: ToolSchema {
        switch self {
        case .readFile:
            return .init(
                type: "object",
                properties: [
                    "path": .init(
                        type: "string",
                        description: "Path to the file"
                    ),
                ],
                required: ["path"]
            )

        case .writeFile:
            return .init(
                type: "object",
                properties: [
                    "path": .init(
                        type: "string",
                        description: "Path to the file"
                    ),
                    "content": .init(
                        type: "string",
                        description: "Content to write"
                    ),
                ],
                required: ["path", "content"]
            )
        case .runCommand:
            return .init(
                type: "object",
                properties: [
                    "command": .init(
                        type: "string",
                        description: "The command to run"
                    ),
                ],
                required: ["command"]
            )
        case .webSearch:
            return .init(
                type: "object",
                properties: [
                    "query": .init(
                        type: "string",
                        description: "Search query"
                    ),
                ],
                required: ["query"]
            )
        }
    }

    public var tool: Tool {
        .init(
            name: self.name,
            description: self.description,
            schema: self.schema
        )
    }
}

public let tools: [Tool] = AvailableTools.allCases.map(\.tool)
