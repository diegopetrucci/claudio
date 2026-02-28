import Foundation

public enum ToolExecutorError: Error, Equatable {
    case runCommandTimedOut(seconds: TimeInterval)
    case runCommandExecutionFailed(command: String, description: String)
    case readFileFailed(path: String, description: String)
    case writeFileCreateDirectoryFailed(path: String, description: String)
    case writeFileWriteContentFailed(path: String, description: String)
    case webSearchNotConfigured
    case webSearchRequestFailed(query: String, description: String)
    case webSearchSerializationFailed(description: String)
}

extension ToolExecutorError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .runCommandTimedOut(seconds):
            return "Command timed out after \(seconds) seconds."
        case let .runCommandExecutionFailed(command, description):
            return "Failed to run command '\(command)': \(description)"
        case let .readFileFailed(path, description):
            return "Failed to read file at '\(path)': \(description)"
        case let .writeFileCreateDirectoryFailed(path, description):
            return "Failed to create parent directory for '\(path)': \(description)"
        case let .writeFileWriteContentFailed(path, description):
            return "Failed to write file at '\(path)': \(description)"
        case .webSearchNotConfigured:
            return "Web search is not configured. Set WEB_SEARCH_API_KEY to enable web_search."
        case let .webSearchRequestFailed(query, description):
            return "Web search request failed for query '\(query)': \(description)"
        case let .webSearchSerializationFailed(description):
            return "Failed to serialize web search output: \(description)"
        }
    }
}
