import Foundation

public enum SessionStoreError: Error {
    case invalidUTF8
    case unableToCreateSessionFile(String)
}

extension SessionStoreError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidUTF8:
            return "SessionStore failed to convert persisted data as UTF-8."
        case let .unableToCreateSessionFile(path):
            return "SessionStore failed to create session file at path: \(path)"
        }
    }
}
