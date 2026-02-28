@testable import claudio
import Foundation
import Testing

@Suite("SystemPromptLoader Tests")
struct SystemPromptLoaderTests {
    @Test("load returns prompt content")
    func loadReturnsPromptContent() throws {
        let tempDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectoryURL) }

        let promptFileURL = tempDirectoryURL.appendingPathComponent("SOUL.md")
        try "You are concise.".write(to: promptFileURL, atomically: true, encoding: .utf8)

        let prompt = try SystemPromptLoader(filePath: promptFileURL.path).load()

        #expect(prompt == "You are concise.")
    }

    @Test("load throws missingFile when file does not exist")
    func loadThrowsMissingFileWhenFileDoesNotExist() throws {
        let tempDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempDirectoryURL) }

        let missingFilePath = tempDirectoryURL
            .appendingPathComponent("SOUL.md")
            .path

        do {
            _ = try SystemPromptLoader(filePath: missingFilePath).load()
            Issue.record("Expected SystemPromptLoaderError.missingFile, but call succeeded.")
        } catch let error as SystemPromptLoaderError {
            guard case .missingFile = error else {
                Issue.record("Expected SystemPromptLoaderError.missingFile, but got \(error).")
                return
            }
        }
    }

    @Test("load throws emptyFile when file has no content")
    func loadThrowsEmptyFileWhenFileHasNoContent() throws {
        let tempDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectoryURL) }

        let promptFileURL = tempDirectoryURL.appendingPathComponent("SOUL.md")
        try "\n\n".write(to: promptFileURL, atomically: true, encoding: .utf8)

        do {
            _ = try SystemPromptLoader(filePath: promptFileURL.path).load()
            Issue.record("Expected SystemPromptLoaderError.emptyFile, but call succeeded.")
        } catch let error as SystemPromptLoaderError {
            guard case .emptyFile = error else {
                Issue.record("Expected SystemPromptLoaderError.emptyFile, but got \(error).")
                return
            }
        }
    }
}
