import Foundation
import Combine

@MainActor
final class TelemetryService: ObservableObject {
    @Published private(set) var snapshot: TelemetrySnapshot = .empty

    private let client: AnthropicUsageClient
    private let profileStore: ProfileStore
    private let ledger: SpendLedger
    private var pollTask: Task<Void, Never>?
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
        pollTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let interval = self.pollIntervalSec
                try? await Task.sleep(nanoseconds: UInt64(interval) * 1_000_000_000)
                await self.refreshOnce()
            }
        }
    }

    func stop() async { pollTask?.cancel(); pollTask = nil }

    func refreshOnce() async {
        if let profile = profileStore.activeProfile,
           let key = profileStore.apiKey(for: profile) {
            await client.setKey(key)
        } else {
            await client.setKey(nil)
        }
        let snap = await client.fetchSnapshot()
        await MainActor.run { self.snapshot = snap }
        ledger.record(snapshot: snap, profileID: profileStore.activeProfile?.id)
    }
}

private extension Int {
    func nonZero(default fallback: Int) -> Int { self == 0 ? fallback : self }
}
