import Foundation
import Combine

#if canImport(GRDB)
import GRDB
#endif

/// Local SQLite-backed spend ledger. Records every telemetry snapshot, exposes day-level rollups.
/// Falls back to in-memory storage when GRDB is unavailable (test/preview).
@MainActor
final class SpendLedger: ObservableObject {
    @Published private(set) var monthToDateUSD: Double = 0
    /// Net all-models tokens consumed this month (sum of per-interval deltas, not
    /// a re-summed cumulative counter). Drives the plan-aware usage-pace forecast.
    @Published private(set) var monthToDateTokens: Double = 0

    /// Last cumulative all-models reading seen, used to derive per-interval deltas.
    /// Seeded from the most recent persisted sample so app restarts don't re-baseline.
    private var lastCumulativeAllModels: Double?

    struct DailySpend: Identifiable, Hashable {
        var date: Date
        var usd: Double
        var id: Date { date }
    }

    #if canImport(GRDB)
    private let dbQueue: DatabaseQueue?
    #endif
    private var memorySamples: [(ts: Date, usd: Double, deltaTokens: Double, profileID: UUID?)] = []

    init() throws {
        #if canImport(GRDB)
        let dir = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("ClaudeHelper", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("ledger.sqlite")
        let queue = try DatabaseQueue(path: url.path)
        try queue.write { db in
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS usage_samples (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    ts REAL NOT NULL,
                    profile_id TEXT,
                    usd REAL NOT NULL,
                    session_used REAL,
                    all_models_used REAL,
                    sonnet_used REAL
                );
                CREATE INDEX IF NOT EXISTS idx_usage_samples_ts ON usage_samples(ts);
            """)
            // Migration: per-interval delta column. Pre-fix rows stored the
            // re-summed cumulative counter in `usd`; `delta_tokens` records the
            // bounded amount actually consumed in that interval.
            let cols = try Row.fetchAll(db, sql: "PRAGMA table_info(usage_samples)")
            if !cols.contains(where: { ($0["name"] as String?) == "delta_tokens" }) {
                try db.execute(sql: "ALTER TABLE usage_samples ADD COLUMN delta_tokens REAL NOT NULL DEFAULT 0")
            }
        }
        self.dbQueue = queue
        // Seed the delta baseline from the latest persisted cumulative reading so
        // a restart attributes only newly-consumed tokens, never the whole counter.
        lastCumulativeAllModels = try? queue.read { db in
            try Double.fetchOne(db, sql: "SELECT all_models_used FROM usage_samples ORDER BY ts DESC LIMIT 1")
        } ?? nil
        #endif
        recomputeMonthToDate()
    }

    static func inMemory() -> SpendLedger {
        let ledger = (try? SpendLedger()) ?? SpendLedger.unsafeInMemory()
        return ledger
    }

    private static func unsafeInMemory() -> SpendLedger {
        var ledger: SpendLedger! = nil
        ledger = try? SpendLedger.__memInit()
        return ledger ?? (try! SpendLedger.__memInit())
    }

    private static func __memInit() throws -> SpendLedger { try SpendLedger(memoryOnly: true) }

    private init(memoryOnly: Bool) throws {
        #if canImport(GRDB)
        self.dbQueue = nil
        #endif
    }

    func record(snapshot: TelemetrySnapshot, profileID: UUID?) {
        let cumulative = snapshot.allModels.used
        let deltaTokens = consumedDelta(currentCumulative: cumulative)
        lastCumulativeAllModels = cumulative
        let usd = estimatedUSD(deltaTokens: deltaTokens)
        let now = Date()
        #if canImport(GRDB)
        if let queue = dbQueue {
            try? queue.write { db in
                try db.execute(sql: """
                    INSERT INTO usage_samples (ts, profile_id, usd, session_used, all_models_used, sonnet_used, delta_tokens)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                """, arguments: [now.timeIntervalSince1970, profileID?.uuidString, usd,
                                 snapshot.session.used, cumulative, snapshot.sonnetOnly.used, deltaTokens])
            }
        } else {
            memorySamples.append((now, usd, deltaTokens, profileID))
        }
        #else
        memorySamples.append((now, usd, deltaTokens, profileID))
        #endif
        recomputeMonthToDate()
    }

    /// Per-interval tokens consumed. A cumulative counter that *drops* means the
    /// usage window reset, so the new reading is fresh consumption (not a negative
    /// delta and not a re-counted full counter). The first sample establishes a
    /// baseline and contributes nothing — we can't attribute prior history to now.
    private func consumedDelta(currentCumulative: Double) -> Double {
        guard let previous = lastCumulativeAllModels else { return 0 }
        return currentCumulative >= previous ? currentCumulative - previous : max(currentCumulative, 0)
    }

    func dailySpendThisMonth() throws -> [DailySpend] {
        let startOfMonth = Calendar.current.dateInterval(of: .month, for: Date())?.start ?? Date()
        #if canImport(GRDB)
        if let queue = dbQueue {
            return try queue.read { db in
                let rows = try Row.fetchAll(db, sql: """
                    SELECT CAST(ts/86400 AS INTEGER)*86400 AS day_bucket, SUM(usd) AS daily
                    FROM usage_samples WHERE ts >= ?
                    GROUP BY day_bucket ORDER BY day_bucket
                """, arguments: [startOfMonth.timeIntervalSince1970])
                return rows.compactMap { row -> DailySpend? in
                    guard let ts: Double = row["day_bucket"], let usd: Double = row["daily"] else { return nil }
                    return DailySpend(date: Date(timeIntervalSince1970: ts), usd: usd)
                }
            }
        }
        #endif
        let grouped = Dictionary(grouping: memorySamples.filter { $0.ts >= startOfMonth }) {
            Calendar.current.startOfDay(for: $0.ts)
        }
        return grouped.map { (day, samples) in
            DailySpend(date: day, usd: samples.reduce(0) { $0 + $1.usd })
        }.sorted { $0.date < $1.date }
    }

    func exportCSV() {
        guard let samples = try? dailySpendThisMonth() else { return }
        let panel = NSSavePanelStub()
        let csv = "date,usd\n" + samples.map { "\(ISO8601DateFormatter().string(from: $0.date)),\($0.usd)" }.joined(separator: "\n")
        let url = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first?
            .appendingPathComponent("claude-helper-spend.csv") ?? URL(fileURLWithPath: "/tmp/claude-helper-spend.csv")
        try? csv.write(to: url, atomically: true, encoding: .utf8)
        Log.info("Exported CSV to \(url.path)")
        _ = panel
    }

    private func recomputeMonthToDate() {
        let startOfMonth = Calendar.current.dateInterval(of: .month, for: Date())?.start ?? Date()
        #if canImport(GRDB)
        if let queue = dbQueue {
            let totals = try? queue.read { db -> (Double, Double) in
                let row = try Row.fetchOne(db, sql: """
                    SELECT COALESCE(SUM(usd), 0) AS usd, COALESCE(SUM(delta_tokens), 0) AS toks
                    FROM usage_samples WHERE ts >= ?
                """, arguments: [startOfMonth.timeIntervalSince1970])
                return (row?["usd"] ?? 0, row?["toks"] ?? 0)
            }
            monthToDateUSD = totals?.0 ?? 0
            monthToDateTokens = totals?.1 ?? 0
            return
        }
        #endif
        let inMonth = memorySamples.filter { $0.ts >= startOfMonth }
        monthToDateUSD = inMonth.reduce(0) { $0 + $1.usd }
        monthToDateTokens = inMonth.reduce(0) { $0 + $1.deltaTokens }
    }

    /// Notional dollar value of incrementally-consumed tokens. Only surfaced for
    /// pay-as-you-go (metered) plans; subscription plans show usage-pace instead.
    /// $30/M is a Sonnet/Opus-mix midpoint until cost_report numbers are wired in.
    private func estimatedUSD(deltaTokens: Double) -> Double {
        let pricePerMillion = 30.0
        return max(deltaTokens, 0) * pricePerMillion / 1_000_000
    }
}

/// Placeholder so the call site compiles in CLI / headless mode without bringing in AppKit save panels.
private struct NSSavePanelStub {}
