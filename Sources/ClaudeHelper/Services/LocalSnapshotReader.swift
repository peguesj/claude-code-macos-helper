import Foundation

/// Reads token usage from the best available local source.
/// Priority: usage-live.json (daemon, ground truth) → stats-cache.json → hook snapshots.
/// "Today" meter = tokens for today's calendar date.
/// "Week" meters = rolling 7-day window.
enum LocalSnapshotReader {
    private static let usageLiveURL = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent(".claude/usage-live.json")
    private static let statsCacheURL = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent(".claude/stats-cache.json")
    private static let snapshotsDir = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent(".claude/usage-snapshots")
    private static let legacyURL = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent(".claude/usage-snapshot.json")

    static func read(plan: Plan) -> TelemetrySnapshot? {
        if let snap = readFromLiveFile(plan: plan) { return snap }
        if let snap = readFromStatsCache(plan: plan) { return snap }
        if let snap = readFromDirectory(plan: plan) { return snap }
        return readFromLegacy(plan: plan)
    }

    // MARK: - usage-live.json (primary — daemon-computed from JSONL transcripts)

    private static func readFromLiveFile(plan: Plan) -> TelemetrySnapshot? {
        guard let data = try? Data(contentsOf: usageLiveURL),
              let raw  = try? JSONDecoder().decode(UsageLive.self, from: data) else { return nil }

        // Reject stale output: daemon must have run within the last 10 minutes
        guard Date().timeIntervalSince(raw.generatedAt) < 600 else { return nil }

        let cal   = Calendar(identifier: .gregorian)
        let today = cal.startOfDay(for: Date())
        let weekReset = cal.date(byAdding: .day, value: 1, to: today)
        let weekResetDate = weekReset

        return TelemetrySnapshot(
            session: TelemetryMeter(
                label: "today", used: Double(raw.today.allModels), limit: 0, resetsAt: weekResetDate
            ),
            allModels: TelemetryMeter(
                label: "all-models", used: Double(raw.week.allModels),
                limit: plan.approxWeekAllModelsLimit, resetsAt: weekResetDate
            ),
            sonnetOnly: TelemetryMeter(
                label: "sonnet", used: 0,
                limit: plan.approxWeekSonnetLimit, resetsAt: weekResetDate
            ),
            lastUpdated: raw.generatedAt
        )
    }

    // MARK: - Stats-cache (secondary fallback)

    private static func readFromStatsCache(plan: Plan) -> TelemetrySnapshot? {
        guard let data = try? Data(contentsOf: statsCacheURL),
              let raw  = try? JSONDecoder().decode(StatsCache.self, from: data) else { return nil }

        let cal   = Calendar(identifier: .gregorian)
        let today = cal.startOfDay(for: Date())
        let cutoff = cal.date(byAdding: .day, value: -6, to: today)!

        var todayAll:    Double = 0
        var weekAll:     Double = 0
        var weekSonnet:  Double = 0

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withFullDate]

        for entry in raw.dailyModelTokens {
            guard let entryDate = iso.date(from: entry.date) else { continue }
            let isToday = cal.isDate(entryDate, inSameDayAs: today)
            let inWindow = entryDate >= cutoff && entryDate <= today

            for (model, tokens) in entry.tokensByModel {
                if isToday { todayAll += tokens }
                if inWindow {
                    weekAll += tokens
                    if model.lowercased().contains("sonnet") { weekSonnet += tokens }
                }
            }
        }

        let weekReset = cal.date(byAdding: .day, value: 1, to: today)
            .map { ISO8601DateFormatter().string(from: $0) }
        let weekResetDate = weekReset.flatMap { ISO8601DateFormatter().date(from: $0) }

        return TelemetrySnapshot(
            session: TelemetryMeter(
                // limit=0: today's cumulative spans multiple rate-limit windows so
                // a percentage against the 5h session limit would be misleading.
                label: "today",     used: todayAll, limit: 0, resetsAt: weekResetDate
            ),
            allModels: TelemetryMeter(
                label: "all-models", used: weekAll,    limit: plan.approxWeekAllModelsLimit, resetsAt: weekResetDate
            ),
            sonnetOnly: TelemetryMeter(
                label: "sonnet",    used: weekSonnet, limit: plan.approxWeekSonnetLimit, resetsAt: weekResetDate
            ),
            lastUpdated: Date()
        )
    }

    // MARK: - Per-session hook snapshots (fallback)

    private static func readFromDirectory(plan: Plan) -> TelemetrySnapshot? {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: snapshotsDir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles
        ) else { return nil }

        let sorted = contents.filter { $0.pathExtension == "json" }.sorted { a, b in
            let da = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let db = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return da > db
        }
        for url in sorted {
            if let snap = decodeHookSnapshot(url: url, plan: plan) { return snap }
        }
        return nil
    }

    private static func readFromLegacy(plan: Plan) -> TelemetrySnapshot? {
        decodeHookSnapshot(url: legacyURL, plan: plan)
    }

    private static func decodeHookSnapshot(url: URL, plan: Plan) -> TelemetrySnapshot? {
        guard let data = try? Data(contentsOf: url),
              let raw  = try? JSONDecoder().decode(HookSnapshot.self, from: data) else { return nil }
        guard Date().timeIntervalSince(raw.updatedAt) < 7200 else { return nil }
        return raw.toTelemetrySnapshot(plan: plan)
    }
}

// MARK: - usage-live.json Codable

private struct UsageLive: Decodable {
    let generatedAt: Date
    let today: DayTotals
    let week: WeekTotals

    struct DayTotals:  Decodable { let date: String; let allModels: Int }
    struct WeekTotals: Decodable { let startDate: String; let allModels: Int }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        today = try c.decode(DayTotals.self,  forKey: .today)
        week  = try c.decode(WeekTotals.self, forKey: .week)
        let iso = try c.decode(String.self,   forKey: .generatedAt)
        generatedAt = ISO8601DateFormatter().date(from: iso) ?? .distantPast
    }
    enum CodingKeys: String, CodingKey { case generatedAt, today, week }
}

// MARK: - Stats-cache Codable

private struct StatsCache: Decodable {
    let dailyModelTokens: [DayEntry]
    struct DayEntry: Decodable {
        let date: String
        let tokensByModel: [String: Double]
    }
}

// MARK: - Hook snapshot Codable (fallback)

private struct HookSnapshot: Decodable {
    let session: SessionInfo
    let week: WeekInfo
    let updatedAt: Date

    struct SessionInfo: Decodable { let tokens: Double; let estimatedResetsAt: String? }
    struct WeekInfo:   Decodable { let allModelsTokens: Double; let sonnetTokens: Double; let estimatedResetsAt: String? }

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
        return TelemetrySnapshot(
            session:    TelemetryMeter(label: "today",      used: session.tokens,       limit: plan.approxSessionTokenLimit,  resetsAt: session.estimatedResetsAt.flatMap { fmt.date(from: $0) }),
            allModels:  TelemetryMeter(label: "all-models", used: week.allModelsTokens, limit: plan.approxWeekAllModelsLimit, resetsAt: week.estimatedResetsAt.flatMap    { fmt.date(from: $0) }),
            sonnetOnly: TelemetryMeter(label: "sonnet",     used: week.sonnetTokens,    limit: plan.approxWeekSonnetLimit,    resetsAt: week.estimatedResetsAt.flatMap    { fmt.date(from: $0) }),
            lastUpdated: updatedAt
        )
    }
}
