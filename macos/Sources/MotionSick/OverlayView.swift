import AppKit

/// Pure renderer for the crisp peripheral cue dots. All physics lives in
/// `MotionEngine`; this view just reads the shared offset and draws.
final class OverlayView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        MotionEngine.shared.register(self)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        let s = Settings.shared
        let b = bounds
        let offsetX = MotionEngine.shared.offsetX
        let offsetY = MotionEngine.shared.offsetY

        if s.tintEnabled {
            let warmth = CGFloat(s.tintWarmth)
            NSColor(calibratedRed: 0.9 + 0.1 * warmth,
                    green: 0.55 + 0.25 * (1 - warmth),
                    blue: 0.35 + 0.45 * (1 - warmth),
                    alpha: CGFloat(s.tintOpacity)).setFill()
            b.fill(using: .sourceOver)
        }

        // Apple-style presence: when enabled, dots rest subtly and swell in as
        // motion grows, instead of sitting at full strength all the time.
        let level = MotionEngine.shared.motionLevel
        let opacityScale: CGFloat = s.fadeWithMotion ? (0.32 + 0.68 * min(1, level)) : 1
        let sizeScale: CGFloat = s.fadeWithMotion ? (0.85 + 0.30 * min(1, level)) : 1

        s.dotColor.withAlphaComponent(CGFloat(s.opacity) * opacityScale).setFill()

        let size = CGFloat(s.dotSize) * sizeScale
        let spacing = max(CGFloat(s.spacing), 18)
        let margin: CGFloat = 26
        var points: [CGPoint] = []

        var x = margin
        while x <= b.width - margin {
            if s.edgeTop { points.append(CGPoint(x: x, y: b.height - margin)) }
            if s.edgeBottom { points.append(CGPoint(x: x, y: margin)) }
            x += spacing
        }
        var y = margin
        while y <= b.height - margin {
            if s.edgeLeft { points.append(CGPoint(x: margin, y: y)) }
            if s.edgeRight { points.append(CGPoint(x: b.width - margin, y: y)) }
            y += spacing
        }

        for p in points {
            let rect = NSRect(x: p.x + offsetX - size / 2, y: p.y + offsetY - size / 2, width: size, height: size)
            NSBezierPath(ovalIn: rect).fill()
        }
    }
}
