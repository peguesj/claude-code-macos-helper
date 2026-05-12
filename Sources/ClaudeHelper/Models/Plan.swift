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
}
