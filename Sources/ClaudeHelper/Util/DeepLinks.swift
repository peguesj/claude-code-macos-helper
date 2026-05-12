import AppKit

enum DeepLinks {
    enum Destination {
        case plan, spendLimit, autoReload, extraUsage, billing, usage, console

        var url: URL {
            switch self {
            case .plan:       return URL(string: "https://claude.ai/settings/plans")!
            case .spendLimit: return URL(string: "https://claude.ai/settings/usage_limits")!
            case .autoReload: return URL(string: "https://claude.ai/settings/auto_reload")!
            case .extraUsage: return URL(string: "https://claude.ai/settings/usage_limits#extra")!
            case .billing:    return URL(string: "https://claude.ai/settings/billing")!
            case .usage:      return URL(string: "https://claude.ai/settings/usage")!
            case .console:    return URL(string: "https://console.anthropic.com/")!
            }
        }
    }

    static func open(_ destination: Destination) { openURL(destination.url) }

    static func openURL(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
}
