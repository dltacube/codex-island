import Foundation

/// A single billable unit of token consumption parsed from a local session log.
/// Both `ClaudeLogReader` and `CodexLogReader` emit these so the cost pipeline
/// downstream is provider-agnostic.
struct TokenEvent {
    enum Provider: String, Codable {
        case claude
        case codex
        case grok
        case antigravity
        case muse
    }

    let provider: Provider
    let timestamp: Date
    let model: String
    let inputTokens: Int
    let outputTokens: Int
    /// Tokens written to the prompt cache during this turn. Anthropic-only.
    let cacheCreationTokens: Int
    /// Tokens served from the prompt cache during this turn. Both providers
    /// (Codex calls these "cached_input_tokens" — they are billed at a
    /// discount but still draw from the input bucket).
    let cacheReadTokens: Int
    var recordID: String? = nil
    var recordAliases: [String] = []
    var sourceFileIdentity: String? = nil
}

struct UsageSourceFile: Equatable {
    let identity: String
    let modifiedAt: Date
    let size: Int64
    let parserVersion: Int

    func matches(_ other: UsageSourceFile) -> Bool {
        size == other.size && parserVersion == other.parserVersion
            && abs(modifiedAt.timeIntervalSinceReferenceDate
                   - other.modifiedAt.timeIntervalSinceReferenceDate) < 0.001
    }
}

struct UsageSourceScan {
    let events: [TokenEvent]
    let files: [UsageSourceFile]
    let changedFileIdentities: Set<String>
    let isComplete: Bool
}

struct UsageScanContext {
    let files: [String: UsageSourceFile]
    let needsBootstrap: Bool
}
