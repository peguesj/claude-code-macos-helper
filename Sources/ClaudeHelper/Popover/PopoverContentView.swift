import SwiftUI

struct PopoverContentView: View {
    @EnvironmentObject var telemetry: TelemetryService
    @EnvironmentObject var profileStore: ProfileStore
    @State private var selectedTab: Tab

    init(initialTab: Tab = .overview) {
        _selectedTab = State(initialValue: initialTab)
    }

    enum Tab: String, CaseIterable, Identifiable {
        case overview, profiles, limits, spend, settings
        var id: String { rawValue }
        var title: String {
            switch self {
            case .overview: return "Overview"
            case .profiles: return "Profiles"
            case .limits:   return "Limits"
            case .spend:    return "Spend"
            case .settings: return "Settings"
            }
        }
        var systemImage: String {
            switch self {
            case .overview: return "gauge.with.dots.needle.50percent"
            case .profiles: return "person.crop.circle.badge.checkmark"
            case .limits:   return "speedometer"
            case .spend:    return "dollarsign.circle"
            case .settings: return "gearshape"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            tabBar
            Divider()
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(14)
        }
        .frame(width: 420, height: 520)
        .background(.regularMaterial)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "circle.dashed.inset.filled")
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(profileStore.activeProfile?.swiftUIAccent ?? Color.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text("Claude Helper").font(.headline)
                if let profile = profileStore.activeProfile {
                    HStack(spacing: 4) {
                        Text(profile.name).font(.caption).foregroundStyle(.secondary)
                        Text("•").foregroundStyle(.tertiary).font(.caption)
                        Text(profile.plan.displayName).font(.caption).foregroundStyle(.secondary)
                    }
                } else {
                    Text("No profile yet").font(.caption).foregroundStyle(.tertiary)
                }
            }
            Spacer()
            Button {
                Task { await telemetry.refreshOnce() }
            } label: {
                Image(systemName: "arrow.clockwise").imageScale(.medium)
            }
            .buttonStyle(.borderless)
            .help("Refresh telemetry")
        }
        .padding(12)
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.systemImage).font(.system(size: 14))
                        Text(tab.title).font(.system(size: 10))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .foregroundStyle(selectedTab == tab ? Color.accentColor : .secondary)
                    .background(selectedTab == tab ? Color.accentColor.opacity(0.12) : .clear)
                }
                .buttonStyle(.borderless)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch selectedTab {
        case .overview: OverviewTab()
        case .profiles: ProfilesTab()
        case .limits:   LimitsTab()
        case .spend:    SpendTab()
        case .settings: SettingsTab()
        }
    }
}
