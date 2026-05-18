import Foundation

/// Reads ~/.claude/usage-snapshot.json written by the PostToolUse hook bridge.
/// Returns nil if the file is absent, unparseable, or older than 2 hours.
enum LocalSnapshotReader {
    static let snapshotURL = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent(".claude/usage-snapshot.json")

    static func read(plan: Plan) -> TelemetrySnapshot? {
        guard let data = try? Data(contentsOf: snapshotURL),
              let raw = try? JSONDecoder().decode(RawSnapshot.self, from: data) else {
            return nil
        }
        guard Date().timeIntervalSince(raw.updatedAt) < 7200 else { return nil }
        return raw.toTelemetrySnapshot(plan: plan)
    }
}

// MARK: - Codable types

private struct RawSnapshot: Decodable {
    let session: SessionInfo
    let week: WeekInfo
    let updatedAt: Date

    struct SessionInfo: Decodable {
        let tokens: Double
        let estimatedResetsAt: String?
    }
    struct WeekInfo: Decodable {
        let allModelsTokens: Double
        let sonnetTokens: Double
        let estimatedResetsAt: String?
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        session   = try c.decode(SessionInfo.self, forKey: .session)
        week      = try c.decode(WeekInfo.self,    forKey: .week)
        let iso   = try c.decode(String.self,      forKey: .updatedAt)
        updatedAt = ISO8601DateFormatter().date(from: iso) ?? .distantPast
    }

    enum CodingKeys: String, CodingKey { case session, week, updatedAt }

    func toTelemetrySnapshot(plan: Plan) -> TelemetrySnapshot {
        let fmt = ISO8601DateFormatter()
        let sessionReset = session.estimatedResetsAt.flatMap { fmt.date(from: $0) }
        let weekReset    = week.estimatedResetsAt.flatMap    { fmt.date(from: $0) }

        return TelemetrySnapshot(
            session: TelemetryMeter(
                label: "session", used: session.tokens,
                limit: plan.approxSessionTokenLimit, resetsAt: sessionReset
            ),
            allModels: TelemetryMeter(
                label: "all-models", used: week.allModelsTokens,
                limit: plan.approxWeekAllModelsLimit, resetsAt: weekReset
            ),
            sonnetOnly: TelemetryMeter(
                label: "sonnet", used: week.sonnetTokens,
                limit: plan.approxWeekSonnetLimit, resetsAt: weekReset
            ),
            lastUpdated: updatedAt
        )
    }
}
