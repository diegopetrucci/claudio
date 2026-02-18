enum AnthropicModel: String, CaseIterable, Sendable {
    case opus
    case sonnet
    case haiku
    
    var apiValue: String {
        switch self {
        case .opus:
            return "claude-opus-4-6"
        case .sonnet:
            return "claude-sonnet-4-6"
        case .haiku:
            return "claude-haiku-4-5@20251001"
        }
    }
}

extension AnthropicModel {
    init?(environmentValue: String) {
        self.init(rawValue: environmentValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }
}

