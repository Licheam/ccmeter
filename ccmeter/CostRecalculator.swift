import Foundation

enum CostRecalculator {

    private static let tieredThreshold = 200_000

    static func costFromTokens(
        input: Int,
        output: Int,
        cacheCreation: Int,
        cacheRead: Int,
        pricing: ModelPricing
    ) -> Double {
        let inputCost = tieredCost(
            tokens: input,
            base: pricing.inputCostPerToken,
            tiered: pricing.inputCostPerTokenAbove200kTokens
        )
        let outputCost = tieredCost(
            tokens: output,
            base: pricing.outputCostPerToken,
            tiered: pricing.outputCostPerTokenAbove200kTokens
        )
        let cacheCreateCost = tieredCost(
            tokens: cacheCreation,
            base: pricing.cacheCreationInputTokenCost,
            tiered: pricing.cacheCreationInputTokenCostAbove200kTokens
        )
        let cacheReadCost = tieredCost(
            tokens: cacheRead,
            base: pricing.cacheReadInputTokenCost,
            tiered: pricing.cacheReadInputTokenCostAbove200kTokens
        )
        return inputCost + outputCost + cacheCreateCost + cacheReadCost
    }

    private static func tieredCost(tokens: Int, base: Double?, tiered: Double?) -> Double {
        guard tokens > 0 else { return 0 }
        if tokens > tieredThreshold, let tiered = tiered {
            let below = min(tokens, tieredThreshold)
            let above = max(0, tokens - tieredThreshold)
            var c = Double(above) * tiered
            if let base = base {
                c += Double(below) * base
            }
            return c
        }
        if let base = base {
            return Double(tokens) * base
        }
        return 0
    }

    // MARK: - Apply to reports

    static func apply(_ overrides: PricingOverrides, to report: DailyReport) -> DailyReport {
        let newDaily = report.daily.map { recompute(entry: $0, overrides: overrides) }
        return DailyReport(daily: newDaily, totals: aggregate(daily: newDaily))
    }

    static func apply(_ overrides: PricingOverrides, to report: SessionReport) -> SessionReport {
        let newSessions = report.sessions.map { recompute(session: $0, overrides: overrides) }
        return SessionReport(sessions: newSessions, totals: aggregate(sessions: newSessions))
    }

    static func apply(
        _ overrides: PricingOverrides,
        to report: BlocksReport,
        newDaily: DailyReport,
        originalDaily: DailyReport
    ) -> BlocksReport {
        let newBlocks = report.blocks.map { block -> BlockEntry in
            let ratio = blockRatio(block: block, newDaily: newDaily, originalDaily: originalDaily)
            return scale(block: block, ratio: ratio)
        }
        return BlocksReport(blocks: newBlocks)
    }

    // MARK: - Per-entry recompute

    private static func recompute(entry: DailyEntry, overrides: PricingOverrides) -> DailyEntry {
        let mbs = entry.modelBreakdowns?.map { recompute(mb: $0, overrides: overrides) }
        let total: Double? = mbs.map { $0.reduce(0) { $0 + ($1.cost ?? 0) } } ?? entry.totalCost
        return DailyEntry(
            date: entry.date,
            inputTokens: entry.inputTokens,
            outputTokens: entry.outputTokens,
            cacheCreationTokens: entry.cacheCreationTokens,
            cacheReadTokens: entry.cacheReadTokens,
            totalTokens: entry.totalTokens,
            totalCost: total,
            modelsUsed: entry.modelsUsed,
            modelBreakdowns: mbs
        )
    }

    private static func recompute(session: SessionEntry, overrides: PricingOverrides) -> SessionEntry {
        let mbs = session.modelBreakdowns?.map { recompute(mb: $0, overrides: overrides) }
        let total: Double? = mbs.map { $0.reduce(0) { $0 + ($1.cost ?? 0) } } ?? session.totalCost
        return SessionEntry(
            sessionId: session.sessionId,
            inputTokens: session.inputTokens,
            outputTokens: session.outputTokens,
            cacheCreationTokens: session.cacheCreationTokens,
            cacheReadTokens: session.cacheReadTokens,
            totalTokens: session.totalTokens,
            totalCost: total,
            lastActivity: session.lastActivity,
            modelsUsed: session.modelsUsed,
            modelBreakdowns: mbs,
            projectPath: session.projectPath
        )
    }

    private static func recompute(mb: ModelBreakdown, overrides: PricingOverrides) -> ModelBreakdown {
        guard let pricing = overrides.lookup(modelName: mb.modelName) else {
            return mb
        }
        let newCost = costFromTokens(
            input: mb.inputTokens ?? 0,
            output: mb.outputTokens ?? 0,
            cacheCreation: mb.cacheCreationTokens ?? 0,
            cacheRead: mb.cacheReadTokens ?? 0,
            pricing: pricing
        )
        return ModelBreakdown(
            modelName: mb.modelName,
            inputTokens: mb.inputTokens,
            outputTokens: mb.outputTokens,
            cacheCreationTokens: mb.cacheCreationTokens,
            cacheReadTokens: mb.cacheReadTokens,
            cost: newCost
        )
    }

    private static func aggregate(daily: [DailyEntry]) -> UsageTotals {
        UsageTotals(
            inputTokens: daily.compactMap { $0.inputTokens }.reduce(0, +),
            outputTokens: daily.compactMap { $0.outputTokens }.reduce(0, +),
            cacheCreationTokens: daily.compactMap { $0.cacheCreationTokens }.reduce(0, +),
            cacheReadTokens: daily.compactMap { $0.cacheReadTokens }.reduce(0, +),
            totalCost: daily.compactMap { $0.totalCost }.reduce(0, +),
            totalTokens: daily.compactMap { $0.totalTokens }.reduce(0, +)
        )
    }

    private static func aggregate(sessions: [SessionEntry]) -> UsageTotals {
        UsageTotals(
            inputTokens: sessions.compactMap { $0.inputTokens }.reduce(0, +),
            outputTokens: sessions.compactMap { $0.outputTokens }.reduce(0, +),
            cacheCreationTokens: sessions.compactMap { $0.cacheCreationTokens }.reduce(0, +),
            cacheReadTokens: sessions.compactMap { $0.cacheReadTokens }.reduce(0, +),
            totalCost: sessions.compactMap { $0.totalCost }.reduce(0, +),
            totalTokens: sessions.compactMap { $0.totalTokens }.reduce(0, +)
        )
    }

    // MARK: - Block scaling

    private static func blockRatio(
        block: BlockEntry,
        newDaily: DailyReport,
        originalDaily: DailyReport
    ) -> Double {
        let dayKey = String(block.startTime.prefix(10))
        if let newEntry = newDaily.daily.first(where: { $0.date == dayKey }),
           let oldEntry = originalDaily.daily.first(where: { $0.date == dayKey }),
           let oldCost = oldEntry.totalCost, oldCost > 0 {
            return (newEntry.totalCost ?? 0) / oldCost
        }
        let oldSum = originalDaily.daily.compactMap { $0.totalCost }.reduce(0, +)
        let newSum = newDaily.daily.compactMap { $0.totalCost }.reduce(0, +)
        return oldSum > 0 ? newSum / oldSum : 1.0
    }

    private static func scale(block: BlockEntry, ratio: Double) -> BlockEntry {
        let newCost = block.costUSD.map { $0 * ratio }
        let newBurn = block.burnRate.map { br in
            BlockBurnRate(
                tokensPerMinute: br.tokensPerMinute,
                tokensPerMinuteForIndicator: br.tokensPerMinuteForIndicator,
                costPerHour: br.costPerHour.map { $0 * ratio }
            )
        }
        let newProj = block.projection.map { p in
            BlockProjection(
                totalTokens: p.totalTokens,
                totalCost: p.totalCost.map { $0 * ratio },
                remainingMinutes: p.remainingMinutes
            )
        }
        return BlockEntry(
            id: block.id,
            startTime: block.startTime,
            endTime: block.endTime,
            actualEndTime: block.actualEndTime,
            isActive: block.isActive,
            isGap: block.isGap,
            entries: block.entries,
            tokenCounts: block.tokenCounts,
            totalTokens: block.totalTokens,
            costUSD: newCost,
            models: block.models,
            burnRate: newBurn,
            projection: newProj
        )
    }
}
