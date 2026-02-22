import Foundation
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

    @Test("web_search throws not implemented")
    func webSearchThrowsNotImplemented() throws {
        let executor = ToolExecutor.live()

        do {
            let query = "swift process"
            _ = try executor.webSearch(query)
            Issue.record("Expected webSearchNotImplemented error, but call succeeded.")
        } catch let error as ToolExecutorError {
            #expect(error == .webSearchNotImplemented(query: "swift process"))
        }
    }
}

private func makeTemporaryDirectoryURL() throws -> URL {
    let directoryURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("ToolExecutorTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    return directoryURL
}
