import SwiftUI
import Charts

struct SpendTab: View {
    @EnvironmentObject var ledger: SpendLedger
    @EnvironmentObject var forecaster: Forecaster
    @State private var dailySpend: [SpendLedger.DailySpend] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(forecaster.isUsagePace ? "All-models this month" : "This month")
                        .font(.caption).foregroundStyle(.secondary)
                    if forecaster.isUsagePace {
                        Text(Forecaster.compact(ledger.monthToDateTokens))
                            .font(.system(size: 28, weight: .medium, design: .rounded))
                    } else {
                        Text(ledger.monthToDateUSD, format: .currency(code: "USD"))
                            .font(.system(size: 28, weight: .medium, design: .rounded))
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Projected").font(.caption).foregroundStyle(.secondary)
                    Group {
                        if forecaster.isUsagePace {
                            Text(forecaster.projectedUsageText)
                        } else {
                            Text(forecaster.projectedMonthEndUSD, format: .currency(code: "USD"))
                        }
                    }
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(forecaster.statusColor)
                }
            }

            if dailySpend.isEmpty {
                Text("No usage recorded yet. Telemetry samples accrue while Claude Helper is running.")
                    .font(.caption).foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
                    .background(Color.gray.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
            } else {
                Chart(dailySpend) { day in
                    BarMark(
                        x: .value("Day", day.date, unit: .day),
                        y: .value("USD", day.usd)
                    )
                    .foregroundStyle(Color.accentColor.gradient)
                }
                .frame(height: 160)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                    }
                }
            }

            HStack(spacing: 8) {
                Label(forecaster.statusLabel, systemImage: forecaster.statusSymbol)
                    .font(.caption)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(forecaster.statusColor.opacity(0.18), in: Capsule())
                    .foregroundStyle(forecaster.statusColor)
                Spacer()
                Button("Export CSV") { ledger.exportCSV() }
                    .buttonStyle(.borderless).font(.caption)
            }

            Spacer()
        }
        .task { dailySpend = (try? ledger.dailySpendThisMonth()) ?? [] }
    }
}
