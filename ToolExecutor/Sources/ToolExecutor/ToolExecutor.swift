import Foundation

public enum ToolExecutorError: Error, Equatable {
    case missingCommand
    case timedOut(seconds: TimeInterval)
}

public struct ToolExecutor: Sendable {
    public var executeTool: @Sendable (String, [String: String]) throws -> String?

    public init(
        executeTool: @escaping @Sendable (String, [String: String]) throws -> String?
    ) {
        self.executeTool = executeTool
    }
}

extension ToolExecutor {
    public static func live(commandTimeout: TimeInterval = 30) -> Self {
        .init(
            executeTool: { name, input in
                guard name == "run_command"
                else { return nil }

                guard let command = input["command"]
                else { throw ToolExecutorError.missingCommand }

                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/sh")
                process.arguments = ["-c", command]

                let stdoutPipe = Pipe()
                let stderrPipe = Pipe()
                process.standardOutput = stdoutPipe
                process.standardError = stderrPipe

                try process.run()

                let deadline = Date().addingTimeInterval(commandTimeout)
                while process.isRunning {
                    guard Date() < deadline
                    else {
                        process.terminate()
                        process.waitUntilExit()
                        throw ToolExecutorError.timedOut(seconds: commandTimeout)
                    }
                    Thread.sleep(forTimeInterval: 0.01)
                }

                let stdout = String(
                    data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(),
                    encoding: .utf8
                ) ?? ""
                let stderr = String(
                    data: stderrPipe.fileHandleForReading.readDataToEndOfFile(),
                    encoding: .utf8
                ) ?? ""
                return stdout + stderr
            }
        )
    }
}
