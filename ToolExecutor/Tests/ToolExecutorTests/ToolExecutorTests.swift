import Foundation
import SearchTool
import Testing
@testable import ToolExecutor

@Suite("ToolExecutor Tests")
struct ToolExecutorTests {
    @Test("run_command returns stdout")
    func runCommandReturnsStdout() throws {
        let executor = ToolExecutor.live()

        let output = try executor.runCommand("printf 'hello world'", 30)

        #expect(output == "hello world")
    }

    @Test("run_command throws when stderr is produced")
    func runCommandThrowsOnStderr() throws {
        let executor = ToolExecutor.live()
        let command = "printf 'hello'; printf ' error' 1>&2"

        do {
            _ = try executor.runCommand(command, 30)
            Issue.record("Expected runCommandExecutionFailed error, but call succeeded.")
        } catch let error as ToolExecutorError {
            switch error {
            case let .runCommandExecutionFailed(failedCommand, description):
                #expect(failedCommand == command)
                #expect(description.contains("error"))
            default:
                Issue.record("Expected runCommandExecutionFailed error, but got \(error).")
            }
        }
    }

    @Test("run_command throws when timeout is reached")
    func runCommandTimesOut() throws {
        let executor = ToolExecutor.live()

        do {
            _ = try executor.runCommand("sleep 1", 0.01)
            Issue.record("Expected runCommandTimedOut error, but call succeeded.")
        } catch let error as ToolExecutorError {
            #expect(error == .runCommandTimedOut(seconds: 0.01))
        }
    }

    @Test("read_file returns file contents")
    func readFileReturnsContents() throws {
        let tempDirectoryURL = try makeTemporaryDirectoryURL()
        defer { try? FileManager.default.removeItem(at: tempDirectoryURL) }

        let fileURL = tempDirectoryURL.appendingPathComponent("sample.txt")
        try "hello".write(to: fileURL, atomically: true, encoding: .utf8)
        let executor = ToolExecutor.live()

        let output = try executor.readFile(fileURL.path)

        #expect(output == "hello")
    }

    @Test("read_file wraps file read failures")
    func readFileFailureIsSpecific() throws {
        let executor = ToolExecutor.live()
        let missingPath = "/tmp/ToolExecutorTests-\(UUID().uuidString)-missing.txt"

        do {
            _ = try executor.readFile(missingPath)
            Issue.record("Expected readFileFailed error, but call succeeded.")
        } catch let error as ToolExecutorError {
            switch error {
            case let .readFileFailed(path, _):
                #expect(path == missingPath)
            default:
                Issue.record("Expected readFileFailed error, but got \(error).")
            }
        }
    }

    @Test("write_file writes content to path")
    func writeFileWritesContent() throws {
        let tempDirectoryURL = try makeTemporaryDirectoryURL()
        defer { try? FileManager.default.removeItem(at: tempDirectoryURL) }

        let fileURL = tempDirectoryURL
            .appendingPathComponent("nested", isDirectory: true)
            .appendingPathComponent("output.txt")
        let executor = ToolExecutor.live()

        try executor.writeFile(fileURL.path, "written")
        let fileContents = try String(contentsOf: fileURL, encoding: .utf8)
        #expect(fileContents == "written")
    }

    @Test("write_file wraps directory creation failures")
    func writeFileCreateDirectoryFailureIsSpecific() throws {
        let tempDirectoryURL = try makeTemporaryDirectoryURL()
        defer { try? FileManager.default.removeItem(at: tempDirectoryURL) }

        let parentFileURL = tempDirectoryURL.appendingPathComponent("parent-file")
        try "x".write(to: parentFileURL, atomically: true, encoding: .utf8)
        let targetPath = parentFileURL
            .appendingPathComponent("output.txt", isDirectory: false)
            .path
        let executor = ToolExecutor.live()

        do {
            try executor.writeFile(targetPath, "written")
            Issue.record("Expected writeFileCreateDirectoryFailed error, but call succeeded.")
        } catch let error as ToolExecutorError {
            switch error {
            case let .writeFileCreateDirectoryFailed(path, _):
                #expect(path == targetPath)
            default:
                Issue.record("Expected writeFileCreateDirectoryFailed error, but got \(error).")
            }
        }
    }

    @Test("write_file wraps content write failures")
    func writeFileContentFailureIsSpecific() throws {
        let tempDirectoryURL = try makeTemporaryDirectoryURL()
        defer { try? FileManager.default.removeItem(at: tempDirectoryURL) }

        let directoryPath = tempDirectoryURL.path
        let executor = ToolExecutor.live()

        do {
            try executor.writeFile(directoryPath, "written")
            Issue.record("Expected writeFileWriteContentFailed error, but call succeeded.")
        } catch let error as ToolExecutorError {
            switch error {
            case let .writeFileWriteContentFailed(path, _):
                #expect(path == directoryPath)
            default:
                Issue.record("Expected writeFileWriteContentFailed error, but got \(error).")
            }
        }
    }

    @Test("web_search throws when not configured")
    func webSearchThrowsWhenNotConfigured() async throws {
        let executor = ToolExecutor.live()

        do {
            let query = "swift process"
            _ = try await executor.webSearch(query)
            Issue.record("Expected webSearchNotConfigured error, but call succeeded.")
        } catch let error as ToolExecutorError {
            #expect(error == .webSearchNotConfigured)
            #expect(error.localizedDescription.contains("WEB_SEARCH_API_KEY"))
        }
    }

    @Test("web_search returns encoded search results")
    func webSearchReturnsEncodedSearchResults() async throws {
        let executor = ToolExecutor.live(
            searchTool: .init(
                search: { query, maxResults in
                    #expect(query == "swift process")
                    #expect(maxResults == 3)
                    return [
                        .init(
                            title: "Swift Process",
                            url: "https://example.com/swift-process",
                            snippet: "How Process works in Swift",
                            pageAge: "2026-01-01T00:00:00Z"
                        ),
                    ]
                }
            ),
            webSearchMaxResults: 3
        )

        let output = try await executor.webSearch("swift process")
        #expect(output.contains("\"query\" : \"swift process\""))
        #expect(output.contains("\"title\" : \"Swift Process\""))
        #expect(output.contains("\"url\" : \"https:\\/\\/example.com\\/swift-process\""))
        #expect(output.contains("\"snippet\" : \"How Process works in Swift\""))
    }

    @Test("web_search wraps search failures")
    func webSearchWrapsSearchFailures() async throws {
        let executor = ToolExecutor.live(
            searchTool: .init(
                search: { _, _ in
                    throw SearchToolError.invalidResponse(description: "bad payload")
                }
            )
        )

        do {
            _ = try await executor.webSearch("swift process")
            Issue.record("Expected webSearchRequestFailed error, but call succeeded.")
        } catch let error as ToolExecutorError {
            switch error {
            case let .webSearchRequestFailed(query, description):
                #expect(query == "swift process")
                #expect(description.contains("bad payload"))
            default:
                Issue.record("Expected webSearchRequestFailed error, but got \(error).")
            }
        }
    }

    @Test("web_search uses injected json encoder")
    func webSearchUsesInjectedJSONEncoder() async throws {
        let jsonEncoder = JSONEncoder()
        jsonEncoder.outputFormatting = [.withoutEscapingSlashes, .sortedKeys]

        let executor = ToolExecutor.live(
            searchTool: .init(
                search: { _, _ in
                    return [
                        .init(
                            title: "Swift Process",
                            url: "https://example.com/swift-process",
                            snippet: "How Process works in Swift",
                            pageAge: nil
                        ),
                    ]
                }
            ),
            jsonEncoder: jsonEncoder
        )

        let output = try await executor.webSearch("swift process")
        #expect(output.contains("\"url\":\"https://example.com/swift-process\""))
    }
}

private func makeTemporaryDirectoryURL() throws -> URL {
    let directoryURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("ToolExecutorTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    return directoryURL
}
