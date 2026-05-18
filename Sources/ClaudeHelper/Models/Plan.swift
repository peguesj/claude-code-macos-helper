import Foundation

struct Plan: Codable, Hashable {
    enum Kind: String, Codable, CaseIterable, Identifiable {
        case free, pro, max5x, max20x, team, enterprise
        var id: String { rawValue }
    }

    var kind: Kind

    var displayName: String {
        switch kind {
        case .free:       return "Free"
        case .pro:        return "Pro"
        case .max5x:      return "Max 5×"
        case .max20x:     return "Max 20×"
        case .team:       return "Team"
        case .enterprise: return "Enterprise"
        }
    }

    var sessionMessageBudget: Double {
        switch kind {
        case .free: return 30
        case .pro: return 80
        case .max5x: return 400
        case .max20x: return 1600
        case .team: return 800
        case .enterprise: return 0 // unmetered / org-defined
        }
    }

    /// Whether token usage on this plan incurs a per-token marginal dollar cost.
    /// Every current plan is a flat-rate subscription (no pay-as-you-go billing),
    /// so a token-extrapolated dollar "spend forecast" is meaningless for them —
    /// the forecast shows a usage-pace projection instead. Reserved `false`/`true`
    /// split so a future pay-as-you-go (API console) kind can opt back into dollars.
    var hasMeteredTokenBilling: Bool {
        switch kind {
        case .free, .pro, .max5x, .max20x, .team, .enterprise:
            return false
        }
    }

    // Approximate 5-hour session window token limits (input + output + cache_creation).
    // Derived empirically: Max 5x at 95% utilisation ≈ 2.015M tokens → limit ≈ 2.12M.
    var approxSessionTokenLimit: Double {
        switch kind {
        case .free:       return    200_000
        case .pro:        return    420_000
        case .max5x:      return  2_100_000
        case .max20x:     return  8_400_000
        case .team:       return    840_000
        case .enterprise: return          0
        }
    }

    // Approximate 7-day all-models rolling window token limit.
    var approxWeekAllModelsLimit: Double {
        switch kind {
        case .free:       return   6_000_000
        case .pro:        return  12_600_000
        case .max5x:      return  63_000_000
        case .max20x:     return 252_000_000
        case .team:       return  25_000_000
        case .enterprise: return           0
        }
    }

    // Approximate 7-day Sonnet-model-only rolling window limit.
    var approxWeekSonnetLimit: Double {
        switch kind {
        case .free:       return  2_000_000
        case .pro:        return  4_200_000
        case .max5x:      return 21_000_000
        case .max20x:     return 84_000_000
        case .team:       return  8_400_000
        case .enterprise: return          0
        }
    }
}
