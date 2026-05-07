import Foundation
import Observation
import AppKit

@MainActor
@Observable
final class UsageStore {

    var daily: DailyReport?
    var session: SessionReport?
    var blocks: BlocksReport?

    var lastError: String?
    var isLoading = false
    var binaryAvailable: Bool = CCUsageRunner.resolveBinary() != nil
    var lastRefreshAt: Date?

    var refreshIntervalSec: Int {
        didSet { restartTimer() }
    }
    var displayMetric: DisplayMetric

    var pricingOverrides: PricingOverrides?
    var pricingOverridesError: String?

    private var rawDaily: DailyReport?
    private var rawSession: SessionReport?
    private var rawBlocks: BlocksReport?

    private var timer: Timer?

    static let customPricingEnabledKey = "customPricingEnabled"
    static let customPricingPathKey = "customPricingPath"
    static let multiplierEnabledKey = "multiplierEnabled"
    static let multiplierKey = "costMultiplier"

    init() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "refreshIntervalSec") == nil {
            defaults.set(30, forKey: "refreshIntervalSec")
        }
        if defaults.string(forKey: "displayMetric") == nil {
            defaults.set(DisplayMetric.cost.rawValue, forKey: "displayMetric")
        }
        if defaults.object(forKey: Self.multiplierKey) == nil {
            defaults.set(1.0, forKey: Self.multiplierKey)
        }
        self.refreshIntervalSec = max(5, defaults.integer(forKey: "refreshIntervalSec"))
        self.displayMetric = DisplayMetric(rawValue: defaults.string(forKey: "displayMetric") ?? "cost") ?? .cost

        loadPricingOverrides()

        observeWorkspace()
        restartTimer()
        Task { await refresh() }
    }

    func setRefreshInterval(_ seconds: Int) {
        let v = max(5, seconds)
        refreshIntervalSec = v
        UserDefaults.standard.set(v, forKey: "refreshIntervalSec")
    }

    func setDisplayMetric(_ m: DisplayMetric) {
        displayMetric = m
        UserDefaults.standard.set(m.rawValue, forKey: "displayMetric")
        NotificationCenter.default.post(name: .ccmeterStatusBarShouldRefresh, object: nil)
    }

    func setBinaryOverride(_ url: URL?) {
        if let url {
            UserDefaults.standard.set(url.path, forKey: CCUsageRunner.userOverrideKey)
        } else {
            UserDefaults.standard.removeObject(forKey: CCUsageRunner.userOverrideKey)
        }
        CCUsageRunner.resetCache()
        binaryAvailable = CCUsageRunner.resolveBinary() != nil
        Task { await refresh() }
    }

    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        guard CCUsageRunner.resolveBinary() != nil else {
            binaryAvailable = false
            lastError = "ccusage executable not found."
            return
        }
        binaryAvailable = true

        do {
            async let dailyData  = CCUsageRunner.run("daily")
            async let sessionData = CCUsageRunner.run("session")
            async let blocksData  = CCUsageRunner.run("blocks")

            let (d, s, b) = try await (dailyData, sessionData, blocksData)
            let decodedDaily   = try CCUsageRunner.decode(d, as: DailyReport.self)
            let decodedSession = try CCUsageRunner.decode(s, as: SessionReport.self)
            let decodedBlocks  = try CCUsageRunner.decode(b, as: BlocksReport.self)
            self.rawDaily   = decodedDaily
            self.rawSession = decodedSession
            self.rawBlocks  = decodedBlocks
            applyOverridesToCachedRaw()
            self.lastError = nil
            self.lastRefreshAt = Date()
            NotificationCenter.default.post(name: .ccmeterStatusBarShouldRefresh, object: nil)
        } catch let e as CCUsageError {
            self.lastError = e.errorDescription
        } catch {
            self.lastError = error.localizedDescription
        }
    }

    private func restartTimer() {
        timer?.invalidate()
        let t = Timer(timeInterval: TimeInterval(refreshIntervalSec), repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func observeWorkspace() {
        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.timer?.invalidate()
                self?.timer = nil
            }
        }
        nc.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.restartTimer()
                await self?.refresh()
            }
        }
    }

    var statusBarString: String {
        let cost = daily?.today?.totalCost ?? 0
        let tokens = daily?.today?.totalTokens ?? 0
        switch displayMetric {
        case .cost:   return Formatting.compactCost(cost)
        case .tokens: return Formatting.compactTokens(tokens)
        case .both:   return "\(Formatting.compactCost(cost)) · \(Formatting.compactTokens(tokens))"
        }
    }

    func setCustomPricing(enabled: Bool, path: String?) {
        let defaults = UserDefaults.standard
        defaults.set(enabled, forKey: Self.customPricingEnabledKey)
        if let path { defaults.set(path, forKey: Self.customPricingPathKey) }
        loadPricingOverrides()
        applyOverridesToCachedRaw()
        NotificationCenter.default.post(name: .ccmeterStatusBarShouldRefresh, object: nil)
    }

    func setMultiplier(enabled: Bool, value: Double) {
        let defaults = UserDefaults.standard
        defaults.set(enabled, forKey: Self.multiplierEnabledKey)
        defaults.set(value, forKey: Self.multiplierKey)
        applyOverridesToCachedRaw()
        NotificationCenter.default.post(name: .ccmeterStatusBarShouldRefresh, object: nil)
    }

    private func loadPricingOverrides() {
        let defaults = UserDefaults.standard
        let enabled = defaults.bool(forKey: Self.customPricingEnabledKey)
        let path = defaults.string(forKey: Self.customPricingPathKey) ?? ""
        guard enabled, !path.isEmpty else {
            pricingOverrides = nil
            pricingOverridesError = nil
            return
        }
        do {
            pricingOverrides = try PricingOverridesLoader.load(fromPath: path)
            pricingOverridesError = nil
        } catch {
            pricingOverrides = nil
            pricingOverridesError = error.localizedDescription
        }
    }

    private func applyOverridesToCachedRaw() {
        guard let rawDaily, let rawSession, let rawBlocks else { return }
        var newDaily: DailyReport
        var newSession: SessionReport
        var newBlocks: BlocksReport
        if let overrides = pricingOverrides {
            newDaily = CostRecalculator.apply(overrides, to: rawDaily)
            newSession = CostRecalculator.apply(overrides, to: rawSession)
            newBlocks = CostRecalculator.apply(
                overrides,
                to: rawBlocks,
                newDaily: newDaily,
                originalDaily: rawDaily
            )
        } else {
            newDaily = rawDaily
            newSession = rawSession
            newBlocks = rawBlocks
        }

        let defaults = UserDefaults.standard
        let mEnabled = defaults.bool(forKey: Self.multiplierEnabledKey)
        let m = defaults.double(forKey: Self.multiplierKey)
        if mEnabled, m > 0, m != 1.0 {
            newDaily = CostRecalculator.applyMultiplier(m, to: newDaily)
            newSession = CostRecalculator.applyMultiplier(m, to: newSession)
            newBlocks = CostRecalculator.applyMultiplier(m, to: newBlocks)
        }

        self.daily = newDaily
        self.session = newSession
        self.blocks = newBlocks
    }
}

extension Notification.Name {
    static let ccmeterStatusBarShouldRefresh = Notification.Name("ccmeterStatusBarShouldRefresh")
}
