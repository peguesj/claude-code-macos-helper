import SwiftUI
import AppKit

struct LimitsTab: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Account-level controls").font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary).textCase(.uppercase)

            Text("Anthropic does not expose plan, billing, or auto-reload controls via API. These buttons deep-link to claude.ai settings pages in your default browser, scoped to the active profile's web session.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 8) {
                row(.plan,       label: "Switch plan",       subtitle: "Free • Pro • Max 5× • Max 20× • Team")
                row(.spendLimit, label: "Spend limit",       subtitle: "Monthly cap on API usage")
                row(.autoReload, label: "Auto-reload",       subtitle: "Toggle automatic top-up")
                row(.extraUsage, label: "Extra usage",       subtitle: "Enable burst above plan cap")
                row(.billing,    label: "Billing & invoices", subtitle: "Payment methods, history")
            }

            Spacer()

            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                Text("Right-click any row to copy the URL.")
            }
            .font(.caption).foregroundStyle(.tertiary)
        }
    }

    private func row(_ link: DeepLinks.Destination, label: String, subtitle: String) -> some View {
        Button {
            DeepLinks.open(link)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label).font(.system(size: 13, weight: .medium))
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.up.forward.app").foregroundStyle(.tertiary)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.gray.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Copy URL") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(link.url.absoluteString, forType: .string)
            }
        }
    }
}
