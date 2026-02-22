import Foundation

public enum ToolExecutorError: Error, Equatable {
    case runCommandTimedOut(seconds: TimeInterval)
    case runCommandExecutionFailed(command: String, description: String)
    case readFileFailed(path: String, description: String)
    case writeFileCreateDirectoryFailed(path: String, description: String)
    case writeFileWriteContentFailed(path: String, description: String)
    case webSearchNotImplemented(query: String)
}
