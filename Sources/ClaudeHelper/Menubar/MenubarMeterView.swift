import AppKit

/// Custom NSView that renders the Claude C-icon plus three inline horizontal meters.
/// The view sits inside `NSStatusItem.button` and updates from `TelemetryService.snapshot`.
final class MenubarMeterView: NSView {
    private var snapshot: TelemetrySnapshot = .empty
    private var accent: NSColor = NSColor(red: 0.80, green: 0.47, blue: 0.36, alpha: 1.0)

    private let iconWidth: CGFloat = 18
    private let meterWidth: CGFloat = 28
    private let meterHeight: CGFloat = 5
    private let meterSpacing: CGFloat = 4
    private let groupSpacing: CGFloat = 6

    override var isFlipped: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        let h = bounds.height
        let centerY = h / 2
        drawClaudeIcon(in: NSRect(x: 1, y: centerY - 8, width: iconWidth, height: 16))

        let meters: [TelemetryMeter] = [snapshot.session, snapshot.allModels, snapshot.sonnetOnly]
        var x: CGFloat = iconWidth + groupSpacing
        for meter in meters {
            drawMeter(meter, in: NSRect(x: x, y: centerY - meterHeight / 2, width: meterWidth, height: meterHeight))
            x += meterWidth + meterSpacing
        }
    }

    override var intrinsicContentSize: NSSize {
        let total = iconWidth + groupSpacing + (meterWidth * 3) + (meterSpacing * 2) + 4
        return NSSize(width: total, height: 22)
    }

    func update(_ snap: TelemetrySnapshot) {
        snapshot = snap
        invalidateIntrinsicContentSize()
        frame.size = intrinsicContentSize
        needsDisplay = true
    }

    func accentForProfile(_ profile: Profile?) {
        accent = profile?.accentColor ?? NSColor(red: 0.80, green: 0.47, blue: 0.36, alpha: 1.0)
        needsDisplay = true
    }

    private func drawClaudeIcon(in rect: NSRect) {
        let path = NSBezierPath()
        let inset: CGFloat = 1.5
        let r = rect.insetBy(dx: inset, dy: inset)
        let radius = r.width / 2
        let center = NSPoint(x: r.midX, y: r.midY)
        path.appendArc(withCenter: center, radius: radius,
                       startAngle: 35, endAngle: 325, clockwise: false)
        path.lineWidth = 1.8
        path.lineCapStyle = .round
        accent.setStroke()
        path.stroke()
    }

    private func drawMeter(_ meter: TelemetryMeter, in rect: NSRect) {
        let radius = rect.height / 2
        let bg = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
        NSColor.tertiaryLabelColor.withAlphaComponent(0.35).setFill()
        bg.fill()

        let ratio = max(0, min(meter.ratio, 1))
        guard ratio > 0 else { return }
        let fillRect = NSRect(x: rect.minX, y: rect.minY,
                              width: max(rect.height, rect.width * ratio),
                              height: rect.height)
        let fg = NSBezierPath(roundedRect: fillRect, xRadius: radius, yRadius: radius)
        colorFor(ratio: ratio).setFill()
        fg.fill()
    }

    private func colorFor(ratio: Double) -> NSColor {
        switch ratio {
        case ..<0.7: return accent
        case ..<0.9: return NSColor.systemOrange
        default:     return NSColor.systemRed
        }
    }
}
