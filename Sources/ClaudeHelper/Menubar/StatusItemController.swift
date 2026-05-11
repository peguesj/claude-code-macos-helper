import AppKit
import SwiftUI
import Combine

@MainActor
final class StatusItemController: NSObject, NSPopoverDelegate {
    private let statusItem: NSStatusItem
    private let meterView: MenubarMeterView
    private let popover: NSPopover
    private var cancellables = Set<AnyCancellable>()

    let telemetry: TelemetryService
    let profileStore: ProfileStore
    let ledger: SpendLedger
    let forecaster: Forecaster

    init(telemetry: TelemetryService,
         profileStore: ProfileStore,
         ledger: SpendLedger,
         forecaster: Forecaster) {
        self.telemetry = telemetry
        self.profileStore = profileStore
        self.ledger = ledger
        self.forecaster = forecaster

        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.meterView = MenubarMeterView()
        self.popover = NSPopover()
        super.init()
    }

    func install() {
        guard let button = statusItem.button else { return }

        meterView.frame = NSRect(x: 0, y: 0, width: 120, height: 22)
        button.addSubview(meterView)
        button.frame = meterView.frame
        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])

        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        popover.contentSize = NSSize(width: 420, height: 520)

        let rootView = PopoverContentView()
            .environmentObject(telemetry)
            .environmentObject(profileStore)
            .environmentObject(ledger)
            .environmentObject(forecaster)
        popover.contentViewController = NSHostingController(rootView: rootView)

        telemetry.$snapshot
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snap in self?.meterView.update(snap) }
            .store(in: &cancellables)

        profileStore.$activeProfile
            .receive(on: DispatchQueue.main)
            .sink { [weak self] p in self?.meterView.accentForProfile(p) }
            .store(in: &cancellables)
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            presentContextMenu(from: sender)
        } else {
            togglePopover(from: sender)
        }
    }

    func togglePopover(from sender: NSView) {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func presentContextMenu(from sender: NSStatusBarButton) {
        let menu = NSMenu()
        menu.addItem(.init(title: "Refresh now", action: #selector(refreshNow), keyEquivalent: "r")).target = self
        menu.addItem(.separator())
        for profile in profileStore.profiles {
            let item = NSMenuItem(title: profile.name, action: #selector(switchProfile(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = profile.id.uuidString
            item.state = (profile.id == profileStore.activeProfile?.id) ? .on : .off
            menu.addItem(item)
        }
        menu.addItem(.separator())
        menu.addItem(.init(title: "Open Claude.ai usage", action: #selector(openUsage), keyEquivalent: "")).target = self
        menu.addItem(.init(title: "Quit Claude Helper", action: #selector(quit), keyEquivalent: "q")).target = self
        statusItem.menu = menu
        sender.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func refreshNow() { Task { await telemetry.refreshOnce() } }
    @objc private func openUsage() { DeepLinks.open(.usage) }
    @objc private func quit() { NSApp.terminate(nil) }
    @objc private func switchProfile(_ item: NSMenuItem) {
        guard let id = (item.representedObject as? String).flatMap(UUID.init(uuidString:)) else { return }
        try? profileStore.activate(profileID: id)
    }

    var meterViewForScreenshot: MenubarMeterView { meterView }
    var popoverForScreenshot: NSPopover { popover }
}
