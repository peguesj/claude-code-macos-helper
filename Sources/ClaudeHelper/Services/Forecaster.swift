import Foundation
import SwiftUI
import Combine

@MainActor
final class Forecaster: ObservableObject {
    struct Alert: Identifiable, Hashable {
        let id = UUID()
        let title: String
        let body: String
    }

    /// Metered (pay-as-you-go) projection. Zero for subscription plans, which
    /// have no per-token marginal cost — they use `projectedUsageText` instead.
    @Published private(set) var projectedMonthEndUSD: Double = 0
    /// Token-allotment projection shown for subscription plans, e.g. "3.4M / 5.0M".
    @Published private(set) var projectedUsageText: String = "—"
    /// True when the active plan is a flat-rate subscription: the forecast is a
    /// usage-pace projection (no dollars), not a spend amount.
    @Published private(set) var isUsagePace: Bool = true
    @Published private(set) var caption: String = "projected month-end"
    @Published private(set) var statusLabel: String = "Tracking"
    @Published private(set) var statusSymbol: String = "checkmark.circle"
    @Published private(set) var statusColor: Color = .green

    let alerts = PassthroughSubject<Alert, Never>()

    private let ledger: SpendLedger
    private let profileStore: ProfileStore
    private let telemetry: TelemetryService
    private var cancellables = Set<AnyCancellable>()
    private var lastAlertedRatio: Double = 0

    init(ledger: SpendLedger, profileStore: ProfileStore, telemetry: TelemetryService) {
        self.ledger = ledger
        self.profileStore = profileStore
        self.telemetry = telemetry

        Publishers.Merge4(
            ledger.$monthToDateUSD.map { _ in () },
            ledger.$monthToDateTokens.map { _ in () },
            profileStore.$activeProfile.map { _ in () },
            telemetry.$snapshot.map { _ in () }
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] in self?.recompute() }
        .store(in: &cancellables)

        recompute()
    }

    private var monthProgress: Double {
        let now = Date()
        guard let interval = Calendar.current.dateInterval(of: .month, for: now) else { return 1 }
        let elapsed = now.timeIntervalSince(interval.start)
        return interval.duration > 0 ? max(elapsed / interval.duration, .leastNonzeroMagnitude) : 1
    }

    private func recompute() {
        let metered = profileStore.activeProfile?.plan.hasMeteredTokenBilling ?? false
        isUsagePace = !metered

        let progress = monthProgress
        let ratio: Double

        if metered {
            // Pay-as-you-go: extrapolate net dollars consumed this month to month-end.
            projectedMonthEndUSD = ledger.monthToDateUSD / progress
            let limit = UserDefaults.standard.double(forKey: "spendLimit.usd")
            let activeLimit = limit > 0 ? limit : 100.0
            ratio = projectedMonthEndUSD / activeLimit
            caption = "projected month-end"
        } else {
            // Subscription: project token consumption against the all-models cap.
            projectedMonthEndUSD = 0
            let projectedTokens = ledger.monthToDateTokens / progress
            let cap = telemetry.snapshot.allModels.limit
            ratio = cap > 0 ? projectedTokens / cap : 0
            projectedUsageText = cap > 0
                ? "\(Self.compact(projectedTokens)) / \(Self.compact(cap))"
                : Self.compact(projectedTokens)
            caption = "all-models · projected month-end"
        }

        let threshold = UserDefaults.standard.double(forKey: "notify.spendThreshold")
        let activeThreshold = threshold > 0 ? threshold : 0.8

        switch ratio {
        case ..<0.5:
            statusLabel = "On track"
            statusSymbol = "checkmark.circle"
            statusColor = .green
        case ..<activeThreshold:
            statusLabel = "Approaching"
            statusSymbol = "exclamationmark.triangle"
            statusColor = .yellow
        case ..<1.0:
            statusLabel = "Above threshold"
            statusSymbol = "exclamationmark.octagon"
            statusColor = .orange
            postAlertIfNew(ratio: ratio, threshold: activeThreshold)
        default:
            statusLabel = isUsagePace ? "Over cap pace" : "Over limit"
            statusSymbol = "xmark.octagon.fill"
            statusColor = .red
            postAlertIfNew(ratio: ratio, threshold: activeThreshold)
        }
    }

    private func postAlertIfNew(ratio: Double, threshold: Double) {
        guard ratio - lastAlertedRatio > 0.1 else { return }
        lastAlertedRatio = ratio
        let what = isUsagePace ? "usage" : "spend"
        alerts.send(Alert(
            title: "Claude \(what) forecast",
            body: "Projected month-end \(what) is \(Int(ratio * 100))% of your \(isUsagePace ? "cap" : "limit")."
        ))
    }

    /// Compact token formatting: 3_350_000 → "3.4M", 950_000 → "950K".
    static func compact(_ value: Double) -> String {
        switch value {
        case 1_000_000...:
            return String(format: "%.1fM", value / 1_000_000)
        case 1_000...:
            return String(format: "%.0fK", value / 1_000)
        default:
            return String(format: "%.0f", value)
        }
    }
}
