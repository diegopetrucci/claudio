import Foundation
import Testing
@testable import ToolExecutor

@Suite("Tool Definitions Tests")
struct ToolDefinitionsTests {
    @Test("tools catalog matches expected starting tools")
    func toolsCatalogMatchesExpectedTools() {
        let catalog = tools

        #expect(catalog.map(\.name) == ["run_command", "read_file", "write_file", "web_search"])
        #expect(catalog.map(\.description) == [
            "Execute a shell command and return its output.",
            "Read the contents of a file.",
            "Write content to a file.",
            "Perform a web search and return the results.",
        ])
        #expect(catalog.map(\.schema.required) == [
            ["command"],
            ["path"],
            ["path", "content"],
            ["query"],
        ])
    }

    @Test("tool encodes schema key")
    func toolEncodesSchemaKey() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(AvailableTools.runCommand.tool)
        let json = String(decoding: data, as: UTF8.self)

        #expect(json.contains("\"schema\""))
    }
}
