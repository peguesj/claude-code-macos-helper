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
}
