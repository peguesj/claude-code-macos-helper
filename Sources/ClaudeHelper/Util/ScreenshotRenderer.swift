import AppKit
import SwiftUI

/// Headless renderer used when `CLAUDEHELPER_SCREENSHOT_MODE=1` is set.
/// Produces PNGs for the README under `docs/screenshots/`.
@MainActor
enum ScreenshotRenderer {
    static func renderAll(controller: StatusItemController) {
        let outDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("docs/screenshots", isDirectory: true)
        try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

        renderMenubar(controller: controller, to: outDir.appendingPathComponent("menubar-closeup.png"))
        renderPopover(controller: controller, tab: .overview, to: outDir.appendingPathComponent("popover-overview.png"))
        renderPopover(controller: controller, tab: .profiles, to: outDir.appendingPathComponent("popover-profiles.png"))
        renderPopover(controller: controller, tab: .limits,   to: outDir.appendingPathComponent("popover-limits.png"))
        renderPopover(controller: controller, tab: .spend,    to: outDir.appendingPathComponent("popover-spend.png"))
        Log.info("Screenshots rendered to \(outDir.path)")
    }

    private static func renderMenubar(controller: StatusItemController, to url: URL) {
        let view = controller.meterViewForScreenshot
        let bg = NSView(frame: NSRect(x: 0, y: 0, width: view.frame.width + 24, height: 32))
        bg.wantsLayer = true
        bg.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.85).cgColor
        view.frame.origin = NSPoint(x: 12, y: 5)
        bg.addSubview(view)
        savePNG(of: bg, to: url)
    }

    private static func renderPopover(controller: StatusItemController, tab: PopoverContentView.Tab, to url: URL) {
        let root = PopoverContentView(initialTab: tab)
            .environmentObject(controller.telemetry)
            .environmentObject(controller.profileStore)
            .environmentObject(controller.ledger)
            .environmentObject(controller.forecaster)
        let host = NSHostingView(rootView: root)
        host.frame = NSRect(x: 0, y: 0, width: 420, height: 520)
        host.layoutSubtreeIfNeeded()
        savePNG(of: host, to: url)
    }

    private static func savePNG(of view: NSView, to url: URL) {
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        guard let data = rep.representation(using: .png, properties: [:]) else { return }
        try? data.write(to: url)
    }
}
