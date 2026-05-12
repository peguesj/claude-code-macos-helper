import AppKit
import SwiftUI
import Combine
import UserNotifications

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusController: StatusItemController!
    private var telemetry: TelemetryService!
    private var profileStore: ProfileStore!
    private var spendLedger: SpendLedger!
    private var forecaster: Forecaster!
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        Log.info("ClaudeHelper booting; pid=\(ProcessInfo.processInfo.processIdentifier)")

        profileStore = ProfileStore.shared
        spendLedger = (try? SpendLedger()) ?? SpendLedger.inMemory()
        forecaster = Forecaster(ledger: spendLedger)
        telemetry = TelemetryService(profileStore: profileStore, ledger: spendLedger)

        statusController = StatusItemController(
            telemetry: telemetry,
            profileStore: profileStore,
            ledger: spendLedger,
            forecaster: forecaster
        )
        statusController.install()

        Task.detached {
            _ = try? await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
        }

        Task { [profileStore] in
            await ProfileBootstrap.ensureDefaultProfile(store: profileStore!)
        }

        forecaster.alerts
            .receive(on: DispatchQueue.main)
            .sink { alert in NotificationDispatcher.post(alert) }
            .store(in: &cancellables)

        Task { await telemetry.start() }

        if ProcessInfo.processInfo.environment["CLAUDEHELPER_SCREENSHOT_MODE"] == "1" {
            Task { @MainActor in
                // Wait for bootstrap + first telemetry tick so meters render with real shape
                await ProfileBootstrap.ensureDefaultProfile(store: self.profileStore)
                await self.telemetry.refreshOnce()
                try? await Task.sleep(nanoseconds: 600_000_000)
                ScreenshotRenderer.renderAll(controller: self.statusController)
                NSApp.terminate(nil)
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        Task { await telemetry.stop() }
    }
}
