import Foundation

#if canImport(Sparkle)
import Sparkle

@MainActor
enum UpdaterBridge {
    private static let controller = SPUStandardUpdaterController(
        startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil
    )
    static func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
    static func setLaunchAtLogin(_ enabled: Bool) {
        #if canImport(LaunchAtLogin)
        LaunchAtLoginBridge.set(enabled)
        #else
        _ = enabled
        #endif
    }
}
#else
@MainActor
enum UpdaterBridge {
    static func checkForUpdates() { Log.info("Sparkle not available — skipping update check") }
    static func setLaunchAtLogin(_ enabled: Bool) { Log.info("LaunchAtLogin not wired (enabled=\(enabled))") }
}
#endif

#if canImport(LaunchAtLogin)
import LaunchAtLogin
@MainActor
enum LaunchAtLoginBridge {
    static func set(_ enabled: Bool) { LaunchAtLogin.isEnabled = enabled }
}
#endif
