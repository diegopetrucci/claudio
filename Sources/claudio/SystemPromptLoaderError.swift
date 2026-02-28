import Foundation

enum SystemPromptLoaderError: Error {
    case missingFile(path: String)
    case emptyFile(path: String)
    case unableToReadFile(path: String, underlyingError: Error)
}

extension SystemPromptLoaderError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case let .missingFile(path):
            return "System prompt file is missing at \(path)."
        case let .emptyFile(path):
            return "System prompt file at \(path) is empty."
        case let .unableToReadFile(path, underlyingError):
            return "Unable to read system prompt file at \(path): \(underlyingError.localizedDescription)"
        }
    }
}
