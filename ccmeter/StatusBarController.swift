import AppKit
import SwiftUI

@MainActor
final class StatusBarController: NSObject {

    private let store: UsageStore
    private let updater: Updater
    private let statusItem: NSStatusItem
    private let popover: NSPopover

    init(store: UsageStore, updater: Updater) {
        self.store = store
        self.updater = updater
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        let pop = NSPopover()
        pop.behavior = .transient
        pop.animates = true
        let host = NSHostingController(rootView: PopoverContent(store: store, updater: updater))
        host.sizingOptions = [.preferredContentSize]
        pop.contentViewController = host
        self.popover = pop

        super.init()

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(handleClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.attributedTitle = Formatting.statusBarAttributed("…")
            button.imagePosition = .noImage
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshTitle),
            name: .ccmeterStatusBarShouldRefresh,
            object: nil
        )

        startTitleObserver()
    }

    @objc private func refreshTitle() {
        guard let button = statusItem.button else { return }
        let text: String
        if !store.binaryAvailable {
            text = "—"
        } else if store.daily == nil {
            text = "…"
        } else {
            text = store.statusBarString
        }
        button.attributedTitle = Formatting.statusBarAttributed(text)
    }

    private func startTitleObserver() {
        refreshTitle()
        withObservationTracking {
            _ = store.statusBarString
            _ = store.binaryAvailable
            _ = store.daily
        } onChange: { [weak self] in
            DispatchQueue.main.async {
                self?.startTitleObserver()
            }
        }
    }

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else {
            togglePopover()
            return
        }
        if event.type == .rightMouseUp {
            showContextMenu(from: sender)
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
            return
        }
        guard let button = statusItem.button else { return }
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        Task { await store.refresh() }
    }

    private func showContextMenu(from button: NSStatusBarButton) {
        let menu = NSMenu()
        menu.addItem(withTitle: "Refresh Now", action: #selector(menuRefresh), keyEquivalent: "r").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Open ccmeter…", action: #selector(menuOpen), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit ccmeter", action: #selector(menuQuit), keyEquivalent: "q").target = self

        statusItem.menu = menu
        button.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func menuRefresh() {
        Task { await store.refresh() }
    }

    @objc private func menuOpen() {
        togglePopover()
    }

    @objc private func menuQuit() {
        NSApp.terminate(nil)
    }
}
