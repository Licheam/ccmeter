import Foundation
import Observation
import Sparkle

@MainActor
@Observable
final class Updater {

    @ObservationIgnored let controller: SPUStandardUpdaterController

    var automaticallyChecks: Bool {
        didSet {
            controller.updater.automaticallyChecksForUpdates = automaticallyChecks
        }
    }

    var lastUpdateCheckDate: Date? {
        controller.updater.lastUpdateCheckDate
    }

    var currentVersion: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        return short ?? "?"
    }

    init() {
        let c = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        self.controller = c
        self.automaticallyChecks = c.updater.automaticallyChecksForUpdates
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}
