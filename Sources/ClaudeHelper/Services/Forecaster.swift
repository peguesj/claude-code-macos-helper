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

    @Published private(set) var projectedMonthEndUSD: Double = 0
    @Published private(set) var statusLabel: String = "Tracking"
    @Published private(set) var statusSymbol: String = "checkmark.circle"
    @Published private(set) var statusColor: Color = .green

    let alerts = PassthroughSubject<Alert, Never>()

    private let ledger: SpendLedger
    private var cancellables = Set<AnyCancellable>()
    private var lastAlertedRatio: Double = 0

    init(ledger: SpendLedger) {
        self.ledger = ledger
        ledger.$monthToDateUSD
            .receive(on: DispatchQueue.main)
            .sink { [weak self] mtd in self?.recompute(monthToDate: mtd) }
            .store(in: &cancellables)
    }

    private func recompute(monthToDate: Double) {
        let now = Date()
        guard let interval = Calendar.current.dateInterval(of: .month, for: now) else { return }
        let elapsed = now.timeIntervalSince(interval.start)
        let total = interval.duration
        let progress = total > 0 ? elapsed / total : 0
        projectedMonthEndUSD = progress > 0 ? monthToDate / progress : monthToDate

        let limit = UserDefaults.standard.double(forKey: "spendLimit.usd")
        let activeLimit = limit > 0 ? limit : 100.0
        let ratio = projectedMonthEndUSD / activeLimit

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
            statusLabel = "Over limit"
            statusSymbol = "xmark.octagon.fill"
            statusColor = .red
            postAlertIfNew(ratio: ratio, threshold: activeThreshold)
        }
    }

    private func postAlertIfNew(ratio: Double, threshold: Double) {
        guard ratio - lastAlertedRatio > 0.1 else { return }
        lastAlertedRatio = ratio
        alerts.send(Alert(
            title: "Claude spend forecast",
            body: "Projected month-end spend is \(Int(ratio * 100))% of your limit."
        ))
    }
}
