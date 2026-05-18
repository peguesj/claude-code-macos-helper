import SwiftUI

struct OverviewTab: View {
    @EnvironmentObject var telemetry: TelemetryService
    @EnvironmentObject var forecaster: Forecaster

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Current usage")
            meterRow(label: "Session", meter: telemetry.snapshot.session)
            meterRow(label: "All models", meter: telemetry.snapshot.allModels)
            meterRow(label: "Sonnet only", meter: telemetry.snapshot.sonnetOnly)

            Divider().padding(.vertical, 4)

            sectionTitle(forecaster.isUsagePace ? "Usage forecast" : "Spend forecast")
            HStack(alignment: .firstTextBaseline) {
                if forecaster.isUsagePace {
                    Text(forecaster.projectedUsageText)
                        .font(.system(size: 28, weight: .medium, design: .rounded))
                } else {
                    Text(forecaster.projectedMonthEndUSD, format: .currency(code: "USD"))
                        .font(.system(size: 28, weight: .medium, design: .rounded))
                }
                Spacer()
                Text(forecaster.caption).font(.caption).foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Label(forecaster.statusLabel, systemImage: forecaster.statusSymbol)
                    .font(.caption)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(forecaster.statusColor.opacity(0.18), in: Capsule())
                    .foregroundStyle(forecaster.statusColor)
                Spacer()
            }
            Spacer()
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }

    private func meterRow(label: String, meter: TelemetryMeter) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.system(size: 13))
                Spacer()
                Text("\(Int(meter.used)) / \(Int(meter.limit))")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: meter.ratio)
                .progressViewStyle(.linear)
                .tint(meterColor(meter.ratio))
        }
    }

    private func meterColor(_ ratio: Double) -> Color {
        switch ratio {
        case ..<0.7: return .claudeClay
        case ..<0.9: return .claudeWarn
        default:     return .claudeDanger
        }
    }
}
