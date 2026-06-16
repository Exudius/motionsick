import AppKit

private func clampD(_ v: CGFloat, _ lo: CGFloat, _ hi: CGFloat) -> CGFloat { min(max(v, lo), hi) }

/// Single source of truth for the cue offset. Owns the one 60 Hz timer (so the
/// motion sources are sampled exactly once per frame regardless of how many
/// screens are showing the overlay), runs the spring physics, and asks every
/// registered overlay view to redraw.
final class MotionEngine {
    static let shared = MotionEngine()

    private(set) var offsetX: CGFloat = 0
    private(set) var offsetY: CGFloat = 0
    /// 0…1 smoothed "how much motion right now", for the Apple-style fade-in.
    private(set) var motionLevel: CGFloat = 0

    private var phase: CGFloat = 0
    private var lastX: CGFloat = 0, lastY: CGFloat = 0
    private var timer: Timer?
    private var views: [OverlayView] = []

    func register(_ v: OverlayView) {
        if !views.contains(where: { $0 === v }) { views.append(v) }
    }
    func clearViews() { views.removeAll() }

    func start() {
        guard timer == nil else { return }
        let t = Timer(timeInterval: 1.0 / 60.0, target: self, selector: #selector(tick), userInfo: nil, repeats: true)
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }
    func stop() { timer?.invalidate(); timer = nil }

    @objc private func tick() {
        let s = Settings.shared
        phase += CGFloat(0.012 + s.speed * 0.09)
        let gain = CGFloat(0.4 + s.intensity * 1.8)

        switch s.mode {
        case .fixed:
            offsetX *= 0.8; offsetY *= 0.8

        case .calm:
            let amp = gain * 22
            let tx = cos(phase) * amp
            let ty = sin(phase * 0.85) * amp * 0.6
            offsetX += (tx - offsetX) * 0.08
            offsetY += (ty - offsetY) * 0.08

        case .sensor:
            if let m = MotionSensor.shared.motion2D() {
                let g = CGFloat(s.sensorGain) * 240
                let tx = clampD(CGFloat(-m.0) * g, -90, 90)
                let ty = clampD(CGFloat(m.1) * g, -90, 90)
                offsetX += (tx - offsetX) * 0.18
                offsetY += (ty - offsetY) * 0.18
            } else {
                driveWithVelocity(MotionFusion.shared.velocity(), gain: gain)
            }

        case .reactive:
            driveWithVelocity(MotionInput.shared.velocity(), gain: gain)

        case .combo:
            driveWithVelocity(MotionFusion.shared.velocity(), gain: gain)
        }

        offsetX = clampD(offsetX, -130, 130)
        offsetY = clampD(offsetY, -130, 130)

        // Apple-style presence: dots swell in with motion (transient speed) and
        // hold while a sustained tilt/acceleration keeps the field displaced,
        // then settle back when everything is still.
        let dx = offsetX - lastX, dy = offsetY - lastY
        lastX = offsetX; lastY = offsetY
        let speedMag = (dx * dx + dy * dy).squareRoot()
        let dispMag = (offsetX * offsetX + offsetY * offsetY).squareRoot() / 130.0
        let raw = min(1, speedMag * 0.22 + dispMag * 0.85)
        motionLevel = motionLevel * 0.85 + raw * 0.15

        for v in views { v.needsDisplay = true }
    }

    /// Velocity-drive integrator: sources push the field, a soft spring pulls it
    /// home so a sustained acceleration holds a steady offset and a transient
    /// glides back — momentum without runaway drift.
    private func driveWithVelocity(_ v: (Double, Double), gain: CGFloat) {
        offsetX += CGFloat(v.0) * gain
        offsetY += CGFloat(v.1) * gain
        let spring: CGFloat = 0.08
        offsetX -= offsetX * spring
        offsetY -= offsetY * spring
    }
}
