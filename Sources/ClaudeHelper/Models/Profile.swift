import Foundation
import AppKit
import SwiftUI

struct Profile: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var plan: Plan
    var accentHex: String
    var createdAt: Date
    var lastUsedAt: Date?

    init(id: UUID = UUID(),
         name: String,
         plan: Plan,
         accentHex: String = "#CC785C",
         createdAt: Date = Date(),
         lastUsedAt: Date? = nil) {
        self.id = id
        self.name = name
        self.plan = plan
        self.accentHex = accentHex
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
    }

    var keychainTag: String { "io.pegues.ClaudeHelper.\(id.uuidString)" }
    var sessionStoreIdentifier: UUID { id }

    var accentColor: NSColor { NSColor(hex: accentHex) ?? NSColor(red: 0.80, green: 0.47, blue: 0.36, alpha: 1.0) }
    var swiftUIAccent: Color { Color(accentColor) }
}

extension NSColor {
    convenience init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        let r = CGFloat((v >> 16) & 0xff) / 255
        let g = CGFloat((v >> 8) & 0xff) / 255
        let b = CGFloat(v & 0xff) / 255
        self.init(srgbRed: r, green: g, blue: b, alpha: 1)
    }
}
