import SwiftUI
import AppKit

/// Claude brand palette from the design handoff (see design_system/colors_and_type.css).
extension Color {
    static let claudeClay      = Color(red: 0.80, green: 0.47, blue: 0.36)              // #CC785C
    static let claudeClayDark  = Color(red: 0.69, green: 0.35, blue: 0.25)              // #B05A40
    static let claudeWarn      = Color(red: 1.00, green: 0.58, blue: 0.00)              // #FF9500
    static let claudeDanger    = Color(red: 1.00, green: 0.23, blue: 0.19)              // #FF3B30
    static let claudeSuccess   = Color(red: 0.20, green: 0.78, blue: 0.35)              // #34C759
}

extension NSColor {
    static let claudeClay = NSColor(srgbRed: 0.80, green: 0.47, blue: 0.36, alpha: 1.0)
}
