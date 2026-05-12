import SwiftUI

struct SettingsTab: View {
    @EnvironmentObject var profileStore: ProfileStore
    @AppStorage("polling.intervalSec") private var pollingInterval: Int = 60
    @AppStorage("notify.spendThreshold") private var notifyThreshold: Double = 0.8
    @AppStorage("ui.compactMenubar") private var compactMenubar: Bool = false
    @AppStorage("launchAtLogin.enabled") private var launchAtLogin = false

    var body: some View {
        Form {
            Section("Telemetry") {
                Stepper(value: $pollingInterval, in: 15...600, step: 15) {
                    Text("Refresh every \(pollingInterval)s")
                }
                Slider(value: $notifyThreshold, in: 0.5...0.95, step: 0.05) {
                    Text("Notify at \(Int(notifyThreshold * 100))% of spend limit")
                }
            }
            Section("Menubar") {
                Toggle("Compact (icon-only when idle)", isOn: $compactMenubar)
            }
            Section("System") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, new in
                        UpdaterBridge.setLaunchAtLogin(new)
                    }
                HStack {
                    Text("Active profile")
                    Spacer()
                    Text(profileStore.activeProfile?.name ?? "—").foregroundStyle(.secondary)
                }
            }
            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(Bundle.main.shortVersionString).foregroundStyle(.secondary)
                }
                Button("Check for updates") { UpdaterBridge.checkForUpdates() }
                Button("Open project on GitHub") {
                    DeepLinks.openURL(URL(string: "https://github.com/peguesj/claude-code-macos-helper")!)
                }
            }
        }
        .formStyle(.grouped)
    }
}
