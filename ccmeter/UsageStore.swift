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

    private var timer: Timer?

    init() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "refreshIntervalSec") == nil {
            defaults.set(30, forKey: "refreshIntervalSec")
        }
        if defaults.string(forKey: "displayMetric") == nil {
            defaults.set(DisplayMetric.cost.rawValue, forKey: "displayMetric")
        }
        self.refreshIntervalSec = max(5, defaults.integer(forKey: "refreshIntervalSec"))
        self.displayMetric = DisplayMetric(rawValue: defaults.string(forKey: "displayMetric") ?? "cost") ?? .cost

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
            self.daily   = try CCUsageRunner.decode(d, as: DailyReport.self)
            self.session = try CCUsageRunner.decode(s, as: SessionReport.self)
            self.blocks  = try CCUsageRunner.decode(b, as: BlocksReport.self)
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
}

extension Notification.Name {
    static let ccmeterStatusBarShouldRefresh = Notification.Name("ccmeterStatusBarShouldRefresh")
}
