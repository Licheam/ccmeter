import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    let store = UsageStore()
    let updater = Updater()
    private var statusBar: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBar = StatusBarController(store: store, updater: updater)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
