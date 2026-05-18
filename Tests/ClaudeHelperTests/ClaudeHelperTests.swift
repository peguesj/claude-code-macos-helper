import XCTest
@testable import ClaudeHelper

final class ClaudeHelperTests: XCTestCase {
    func testMeterRatioClampsToOne() {
        let m = TelemetryMeter(label: "x", used: 200, limit: 100, resetsAt: nil)
        XCTAssertEqual(m.ratio, 1.0, accuracy: 0.001)
    }

    func testMeterRatioZeroWhenLimitMissing() {
        let m = TelemetryMeter(label: "x", used: 50, limit: 0, resetsAt: nil)
        XCTAssertEqual(m.ratio, 0)
    }

    func testPlanDisplayNamesAreNonEmpty() {
        for kind in Plan.Kind.allCases {
            XCTAssertFalse(Plan(kind: kind).displayName.isEmpty)
        }
    }

    func testNSColorHexParses() {
        XCTAssertNotNil(NSColor(hex: "#CC785C"))
        XCTAssertNotNil(NSColor(hex: "CC785C"))
        XCTAssertNil(NSColor(hex: "zzzzzz"))
    }

    func testDeepLinksAllResolve() {
        let cases: [DeepLinks.Destination] = [.plan, .spendLimit, .autoReload, .extraUsage, .billing, .usage, .console]
        for c in cases {
            XCTAssertTrue(c.url.absoluteString.hasPrefix("https://"))
        }
    }

    // Bug B invariant: no current plan is metered, so none may surface a
    // token-extrapolated dollar forecast.
    func testNoCurrentPlanIsMetered() {
        for kind in Plan.Kind.allCases {
            XCTAssertFalse(Plan(kind: kind).hasMeteredTokenBilling,
                           "\(kind) is a flat-rate subscription and must not bill per-token")
        }
    }

    // Regression for the $360k compounding bug: recording the same cumulative
    // usage snapshot repeatedly must NOT keep inflating month-to-date. With the
    // pre-fix code each poll re-summed the whole counter (~$37/poll → unbounded);
    // with delta accounting, identical cumulative readings contribute zero.
    @MainActor
    func testRepeatedConstantSnapshotDoesNotCompound() {
        let ledger = SpendLedger.inMemory()
        let snap = TelemetrySnapshot(
            session:    TelemetryMeter(label: "s", used: 42,        limit: 100,       resetsAt: nil),
            allModels:  TelemetryMeter(label: "a", used: 1_240_000, limit: 5_000_000, resetsAt: nil),
            sonnetOnly: TelemetryMeter(label: "o", used: 380_000,   limit: 2_000_000, resetsAt: nil),
            lastUpdated: Date()
        )
        ledger.record(snapshot: snap, profileID: nil)   // first sample → baseline
        let baseline = ledger.monthToDateUSD
        for _ in 0..<200 { ledger.record(snapshot: snap, profileID: nil) }
        XCTAssertEqual(ledger.monthToDateUSD, baseline, accuracy: 0.0001,
                       "Constant cumulative usage must not compound month-to-date spend")
    }

    // A growing cumulative counter accrues exactly the incremental delta; a
    // counter reset (drop) is treated as fresh consumption, never negative.
    @MainActor
    func testDeltaAccountingAndCounterReset() {
        let ledger = SpendLedger.inMemory()
        func snap(_ used: Double) -> TelemetrySnapshot {
            TelemetrySnapshot(
                session:    TelemetryMeter(label: "s", used: 0, limit: 1, resetsAt: nil),
                allModels:  TelemetryMeter(label: "a", used: used, limit: 5_000_000, resetsAt: nil),
                sonnetOnly: TelemetryMeter(label: "o", used: 0, limit: 1, resetsAt: nil),
                lastUpdated: Date())
        }
        ledger.record(snapshot: snap(1_000_000), profileID: nil) // baseline, +0
        let afterBaseline = ledger.monthToDateTokens
        ledger.record(snapshot: snap(1_300_000), profileID: nil) // +300k
        XCTAssertEqual(ledger.monthToDateTokens - afterBaseline, 300_000, accuracy: 1)
        ledger.record(snapshot: snap(50_000), profileID: nil)    // reset → +50k (not -1.25M)
        XCTAssertEqual(ledger.monthToDateTokens - afterBaseline, 350_000, accuracy: 1)
    }
}
