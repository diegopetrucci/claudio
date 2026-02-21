import Testing
@testable import ToolExecutor

@Suite("ToolExecutor Tests")
struct ToolExecutorTests {
    @Test("run_command returns stdout followed by stderr")
    func runCommandReturnsCombinedOutput() throws {
        let executor = ToolExecutor.live()

        let output = try executor.executeTool(
            "run_command",
            ["command": "printf 'hello'; printf ' world' 1>&2"]
        )

        #expect(output == "hello world")
    }

    @Test("unknown tool returns nil")
    func unknownToolReturnsNil() throws {
        let executor = ToolExecutor.live()

        let output = try executor.executeTool(
            "not_supported",
            ["command": "printf 'hello'"]
        )

        #expect(output == nil)
    }

    @Test("run_command throws when command input is missing")
    func runCommandMissingCommand() throws {
        let executor = ToolExecutor.live()

        do {
            _ = try executor.executeTool("run_command", [:])
            Issue.record("Expected missingCommand error, but call succeeded.")
        } catch let error as ToolExecutorError {
            #expect(error == .missingCommand)
        }
    }

    @Test("run_command throws when timeout is reached")
    func runCommandTimesOut() throws {
        let executor = ToolExecutor.live(commandTimeout: 0.01)

        do {
            _ = try executor.executeTool("run_command", ["command": "sleep 1"])
            Issue.record("Expected timedOut error, but call succeeded.")
        } catch let error as ToolExecutorError {
            #expect(error == .timedOut(seconds: 0.01))
        }
    }
}
