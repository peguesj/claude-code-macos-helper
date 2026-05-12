import Foundation

struct TelemetryMeter: Codable, Hashable {
    var label: String
    var used: Double
    var limit: Double
    var resetsAt: Date?

    var ratio: Double { limit > 0 ? min(used / limit, 1.0) : 0 }
    var remaining: Double { max(limit - used, 0) }

    static let zero = TelemetryMeter(label: "", used: 0, limit: 1, resetsAt: nil)
}

struct TelemetrySnapshot: Codable, Hashable {
    var session: TelemetryMeter
    var allModels: TelemetryMeter
    var sonnetOnly: TelemetryMeter
    var lastUpdated: Date

    static let empty = TelemetrySnapshot(
        session: TelemetryMeter(label: "session", used: 0, limit: 1, resetsAt: nil),
        allModels: TelemetryMeter(label: "all-models", used: 0, limit: 1, resetsAt: nil),
        sonnetOnly: TelemetryMeter(label: "sonnet", used: 0, limit: 1, resetsAt: nil),
        lastUpdated: .distantPast
    )
}
