import Foundation

enum DisplayMetric: String, CaseIterable, Identifiable {
    case cost, tokens, both
    var id: String { rawValue }
    var label: String {
        switch self {
        case .cost: return "Cost"
        case .tokens: return "Tokens"
        case .both: return "Cost + Tokens"
        }
    }
}

struct ModelBreakdown: Codable, Hashable {
    let modelName: String
    let inputTokens: Int?
    let outputTokens: Int?
    let cacheCreationTokens: Int?
    let cacheReadTokens: Int?
    let cost: Double?
}

struct DailyEntry: Codable, Identifiable, Hashable {
    let date: String
    let inputTokens: Int?
    let outputTokens: Int?
    let cacheCreationTokens: Int?
    let cacheReadTokens: Int?
    let totalTokens: Int?
    let totalCost: Double?
    let modelsUsed: [String]?
    let modelBreakdowns: [ModelBreakdown]?

    var id: String { date }
}

struct UsageTotals: Codable, Hashable {
    let inputTokens: Int?
    let outputTokens: Int?
    let cacheCreationTokens: Int?
    let cacheReadTokens: Int?
    let totalCost: Double?
    let totalTokens: Int?
}

struct DailyReport: Codable, Hashable {
    let daily: [DailyEntry]
    let totals: UsageTotals?

    var today: DailyEntry? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        let key = f.string(from: Date())
        return daily.first { $0.date == key }
    }
}

struct SessionEntry: Codable, Identifiable, Hashable {
    let sessionId: String
    let inputTokens: Int?
    let outputTokens: Int?
    let cacheCreationTokens: Int?
    let cacheReadTokens: Int?
    let totalTokens: Int?
    let totalCost: Double?
    let lastActivity: String?
    let modelsUsed: [String]?
    let modelBreakdowns: [ModelBreakdown]?
    let projectPath: String?

    var id: String { sessionId + (lastActivity ?? "") + (projectPath ?? "") }

    var displayName: String {
        if sessionId == "subagents" {
            if let p = projectPath, p != "Unknown Project" {
                return "subagents · \(shortProject(p))"
            }
            return "subagents"
        }
        let parts = sessionId.split(separator: "-").suffix(3)
        return parts.isEmpty ? sessionId : parts.joined(separator: "/")
    }

    private func shortProject(_ p: String) -> String {
        let stripped = p.split(separator: "/").first.map(String.init) ?? p
        return stripped.split(separator: "-").suffix(2).joined(separator: "-")
    }
}

struct SessionReport: Codable, Hashable {
    let sessions: [SessionEntry]
    let totals: UsageTotals?

    var topByCost: [SessionEntry] {
        sessions
            .filter { ($0.totalCost ?? 0) > 0 }
            .sorted { ($0.totalCost ?? 0) > ($1.totalCost ?? 0) }
    }
}

struct BlockTokenCounts: Codable, Hashable {
    let inputTokens: Int?
    let outputTokens: Int?
    let cacheCreationInputTokens: Int?
    let cacheReadInputTokens: Int?
}

struct BlockBurnRate: Codable, Hashable {
    let tokensPerMinute: Double?
    let tokensPerMinuteForIndicator: Double?
    let costPerHour: Double?
}

struct BlockProjection: Codable, Hashable {
    let totalTokens: Int?
    let totalCost: Double?
    let remainingMinutes: Int?
}

struct BlockEntry: Codable, Identifiable, Hashable {
    let id: String
    let startTime: String
    let endTime: String
    let actualEndTime: String?
    let isActive: Bool
    let isGap: Bool
    let entries: Int?
    let tokenCounts: BlockTokenCounts?
    let totalTokens: Int?
    let costUSD: Double?
    let models: [String]?
    let burnRate: BlockBurnRate?
    let projection: BlockProjection?
}

struct BlocksReport: Codable, Hashable {
    let blocks: [BlockEntry]

    var active: BlockEntry? {
        blocks.first { $0.isActive && !$0.isGap }
    }

    var lastNonGap: BlockEntry? {
        blocks.reversed().first { !$0.isGap }
    }
}

enum CCUsageError: Error, LocalizedError {
    case notFound
    case launchFailed(String)
    case nonZeroExit(Int32, String)
    case decode(String)

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "ccusage executable not found on the system."
        case .launchFailed(let msg):
            return "Failed to launch ccusage: \(msg)"
        case .nonZeroExit(let code, let stderr):
            return "ccusage exited with code \(code).\n\(stderr)"
        case .decode(let msg):
            return "Failed to decode ccusage output: \(msg)"
        }
    }
}
