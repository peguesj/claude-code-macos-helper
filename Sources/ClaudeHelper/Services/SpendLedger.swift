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

    struct DailySpend: Identifiable, Hashable {
        var date: Date
        var usd: Double
        var id: Date { date }
    }

    #if canImport(GRDB)
    private let dbQueue: DatabaseQueue?
    #endif
    private var memorySamples: [(ts: Date, usd: Double, profileID: UUID?)] = []

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
        }
        self.dbQueue = queue
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
        let usd = estimatedUSD(for: snapshot)
        let now = Date()
        #if canImport(GRDB)
        if let queue = dbQueue {
            try? queue.write { db in
                try db.execute(sql: """
                    INSERT INTO usage_samples (ts, profile_id, usd, session_used, all_models_used, sonnet_used)
                    VALUES (?, ?, ?, ?, ?, ?)
                """, arguments: [now.timeIntervalSince1970, profileID?.uuidString, usd,
                                 snapshot.session.used, snapshot.allModels.used, snapshot.sonnetOnly.used])
            }
        } else {
            memorySamples.append((now, usd, profileID))
        }
        #else
        memorySamples.append((now, usd, profileID))
        #endif
        recomputeMonthToDate()
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
            let sum = try? queue.read { db in
                try Double.fetchOne(db, sql: "SELECT COALESCE(SUM(usd), 0) FROM usage_samples WHERE ts >= ?",
                                    arguments: [startOfMonth.timeIntervalSince1970]) ?? 0
            }
            monthToDateUSD = sum ?? 0
            return
        }
        #endif
        monthToDateUSD = memorySamples.filter { $0.ts >= startOfMonth }.reduce(0) { $0 + $1.usd }
    }

    private func estimatedUSD(for snapshot: TelemetrySnapshot) -> Double {
        // Approximation: $15/M input + $75/M output is a midpoint guess for Sonnet/Opus mix.
        // Replace with cost_report numbers when API access is available.
        let totalTokens = snapshot.allModels.used
        let pricePerMillion = 30.0
        return totalTokens * pricePerMillion / 1_000_000
    }
}

/// Placeholder so the call site compiles in CLI / headless mode without bringing in AppKit save panels.
private struct NSSavePanelStub {}
