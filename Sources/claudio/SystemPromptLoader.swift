import Foundation

struct SystemPromptLoader {
    private let filePath: String

    init(filePath: String = "SOUL.md") {
        self.filePath = filePath
    }

    func load() throws -> String {
        guard FileManager.default.fileExists(atPath: self.filePath)
        else { throw SystemPromptLoaderError.missingFile(path: self.filePath) }

        do {
            let prompt = try String(contentsOfFile: self.filePath, encoding: .utf8)
            guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else { throw SystemPromptLoaderError.emptyFile(path: self.filePath) }
            return prompt
        } catch let error as SystemPromptLoaderError {
            throw error
        } catch {
            throw SystemPromptLoaderError.unableToReadFile(
                path: self.filePath,
                underlyingError: error
            )
        }
    }
}
