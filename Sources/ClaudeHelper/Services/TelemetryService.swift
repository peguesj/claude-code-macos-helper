import Foundation
import Combine

@MainActor
final class TelemetryService: ObservableObject {
    @Published private(set) var snapshot: TelemetrySnapshot = .empty

    private let client: AnthropicUsageClient
    private let profileStore: ProfileStore
    private let ledger: SpendLedger
    private var pollTask: Task<Void, Never>?
    private var fileWatcher: FileSystemWatcher?
    private var pollIntervalSec: Int {
        UserDefaults.standard.integer(forKey: "polling.intervalSec").nonZero(default: 60)
    }

    init(profileStore: ProfileStore, ledger: SpendLedger) {
        self.profileStore = profileStore
        self.ledger = ledger
        self.client = AnthropicUsageClient(apiKey: profileStore.activeProfile.flatMap { profileStore.apiKey(for: $0) })
    }

    func start() async {
        await refreshOnce()
        startFileWatcher()
        pollTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let interval = self.pollIntervalSec
                try? await Task.sleep(nanoseconds: UInt64(interval) * 1_000_000_000)
                await self.refreshOnce()
            }
        }
    }

    func stop() async {
        pollTask?.cancel()
        pollTask = nil
        fileWatcher?.stop()
        fileWatcher = nil
    }

    private func startFileWatcher() {
        let home = NSHomeDirectory()
        let watcher = FileSystemWatcher(debounce: 0.5) { [weak self] in
            Task { await self?.refreshOnce() }
        }
        watcher.watch(paths: [
            "\(home)/.claude/stats-cache.json",
            "\(home)/.claude/usage-snapshots"
        ])
        fileWatcher = watcher
    }

    func refreshOnce() async {
        let profile = profileStore.activeProfile
        if let key = profile.flatMap({ profileStore.apiKey(for: $0) }) {
            await client.setKey(key)
        } else {
            await client.setKey(nil)
        }
        await client.setPlan(profile?.plan ?? Plan(kind: .max5x))
        let snap = await client.fetchSnapshot()
        await MainActor.run { self.snapshot = snap }
        ledger.record(snapshot: snap, profileID: profile?.id)
    }
}

private extension Int {
    func nonZero(default fallback: Int) -> Int { self == 0 ? fallback : self }
}
