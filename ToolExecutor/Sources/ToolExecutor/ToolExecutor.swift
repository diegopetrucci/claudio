import Foundation
import SearchTool

public struct ToolExecutor: Sendable {
    public var runCommand: @Sendable (String, TimeInterval) throws -> String
    public var readFile: @Sendable (String) throws -> String
    public var writeFile: @Sendable (String, String) throws -> Void
    public var webSearch: @Sendable (String) async throws -> String

    public init(
        runCommand: @escaping @Sendable (String, TimeInterval) throws -> String,
        readFile: @escaping @Sendable (String) throws -> String,
        writeFile: @escaping @Sendable (String, String) throws -> Void,
        webSearch: @escaping @Sendable (String) async throws -> String
    ) {
        self.runCommand = runCommand
        self.readFile = readFile
        self.writeFile = writeFile
        self.webSearch = webSearch
    }
}

extension ToolExecutor {
    public static func live(
        searchTool: SearchTool? = nil,
        webSearchMaxResults: Int = 5,
        jsonEncoder: JSONEncoder = {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            return encoder
        }()
    ) -> Self {
        .init(
            runCommand: { command, timeout in
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/sh")
                process.arguments = ["-c", command]

                let stdoutPipe = Pipe()
                let stderrPipe = Pipe()
                process.standardOutput = stdoutPipe
                process.standardError = stderrPipe

                do {
                    try process.run()
                } catch {
                    throw ToolExecutorError.runCommandExecutionFailed(
                        command: command,
                        description: error.localizedDescription
                    )
                }

                let deadline = Date().addingTimeInterval(timeout)
                while process.isRunning {
                    guard Date() < deadline
                    else {
                        process.terminate()
                        process.waitUntilExit()
                        throw ToolExecutorError.runCommandTimedOut(seconds: timeout)
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

                guard process.terminationStatus == 0
                else {
                    let description = stderr.isEmpty
                        ? "Command exited with status \(process.terminationStatus)."
                        : stderr
                    throw ToolExecutorError.runCommandExecutionFailed(
                        command: command,
                        description: description
                    )
                }

                guard stderr.isEmpty
                else {
                    throw ToolExecutorError.runCommandExecutionFailed(
                        command: command,
                        description: stderr
                    )
                }

                return stdout
            },
            readFile: { path in
                do {
                    return try String(contentsOfFile: path, encoding: .utf8)
                } catch {
                    throw ToolExecutorError.readFileFailed(
                        path: path,
                        description: error.localizedDescription
                    )
                }
            },
            writeFile: { path, content in
                let fileURL = URL(fileURLWithPath: path)
                do {
                    try FileManager.default.createDirectory(
                        at: fileURL.deletingLastPathComponent(),
                        withIntermediateDirectories: true
                    )
                } catch {
                    throw ToolExecutorError.writeFileCreateDirectoryFailed(
                        path: path,
                        description: error.localizedDescription
                    )
                }

                do {
                    try content.write(to: fileURL, atomically: true, encoding: .utf8)
                } catch {
                    throw ToolExecutorError.writeFileWriteContentFailed(
                        path: path,
                        description: error.localizedDescription
                    )
                }
            },
            webSearch: { query in
                guard let searchTool
                else { throw ToolExecutorError.webSearchNotConfigured }

                let results: [SearchResult]
                do {
                    results = try await searchTool.search(query, webSearchMaxResults)
                } catch {
                    throw ToolExecutorError.webSearchRequestFailed(
                        query: query,
                        description: String(describing: error)
                    )
                }

                let output = WebSearchOutput(
                    query: query,
                    results: results
                )
                do {
                    let data = try jsonEncoder.encode(output)
                    return String(decoding: data, as: UTF8.self)
                } catch {
                    throw ToolExecutorError.webSearchSerializationFailed(
                        description: error.localizedDescription
                    )
                }
            }
        )
    }
}

private struct WebSearchOutput: Encodable {
    let query: String
    let results: [SearchResult]
}
