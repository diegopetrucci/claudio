import Foundation

func allowedTelegramChatIDs(from rawValue: String) -> Set<Int64> {
    let segments = rawValue.split(
        separator: ",",
        omittingEmptySubsequences: false
    )
    var parsedIDs = Set<Int64>()
    var invalidSegments: [String] = []
    invalidSegments.reserveCapacity(segments.count)

    for segment in segments {
        let value = String(segment).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, let chatID = Int64(value) else {
            invalidSegments.append(value.isEmpty ? "<empty>" : value)
            continue
        }
        parsedIDs.insert(chatID)
    }

    guard invalidSegments.isEmpty, !parsedIDs.isEmpty
    else {
        fatalError(
            """
            Invalid ALLOWED_TELEGRAM_CHAT_IDS value '\(rawValue)'.
            It must be a comma-separated list of Telegram Int64 chat IDs (e.g. 123456789,-100987654321).
            Invalid entries: \(invalidSegments.joined(separator: ", "))
            """
        )
    }

    return parsedIDs
}
