import AppKit

/// Scroll-wheel + pointer flow as a decaying velocity. Scroll/pointer events
/// kick the velocity; `velocity()` (called once per physics tick) reads it and
/// bleeds it off, giving momentum that fades when you stop. This is one of the
/// fused motion sources — the on-screen flow that itself contributes to screen
/// motion sickness.
final class MotionInput {
    static let shared = MotionInput()

    private var vx = 0.0, vy = 0.0
    private let lock = NSLock()
    private var monitors: [Any] = []

    func install() {
        let scrollMask: NSEvent.EventTypeMask = [.scrollWheel]
        let moveMask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged]

        if let m = NSEvent.addGlobalMonitorForEvents(matching: scrollMask, handler: { [weak self] e in self?.addScroll(e) }) {
            monitors.append(m)
        }
        if let m = NSEvent.addLocalMonitorForEvents(matching: scrollMask, handler: { [weak self] e in self?.addScroll(e); return e }) {
            monitors.append(m)
        }
        if let m = NSEvent.addGlobalMonitorForEvents(matching: moveMask, handler: { [weak self] e in self?.addMove(e) }) {
            monitors.append(m)
        }
    }

    private func addScroll(_ e: NSEvent) {
        guard Settings.shared.scrollEnabled else { return }   // "react to scrolling" toggle
        lock.lock()
        vx += Double(e.scrollingDeltaX) * 0.10
        vy += Double(e.scrollingDeltaY) * 0.10
        lock.unlock()
    }

    private func addMove(_ e: NSEvent) {
        guard Settings.shared.pointerEnabled else { return }   // "follow mouse" toggle
        lock.lock()
        vx += Double(e.deltaX) * 0.04
        vy += Double(-e.deltaY) * 0.04
        lock.unlock()
    }

    /// Current velocity, then decay it. Call exactly once per physics tick.
    func velocity() -> (Double, Double) {
        lock.lock()
        let r = (vx, vy)
        vx *= 0.85; vy *= 0.85
        lock.unlock()
        return r
    }
}
