import Foundation

/// Blends every available real motion source into one velocity vector.
/// Weighting is tuned for vehicles: the device accelerometer (lid) carries the
/// true train/car motion, the camera adds bumps/sway, scroll/pointer adds the
/// on-screen flow. Missing sources simply contribute nothing.
final class MotionFusion {
    static let shared = MotionFusion()

    func velocity() -> (Double, Double) {
        let s = Settings.shared
        let sens = 0.4 + s.sensorGain * 1.6
        var x = 0.0, y = 0.0

        // On-screen flow (always available).
        let mp = MotionInput.shared.velocity()
        x += mp.0 * 0.6
        y += mp.1 * 0.6

        // Device accelerometer — the vehicle-motion hero. Highest weight.
        if s.lidEnabled, let l = LidSensor.shared.velocity() {
            x += l.0 * 9.0 * sens
            y += l.1 * 9.0 * sens
        }

        // Camera optical flow — bumps / relative sway. Image y is top-down → flip.
        if s.cameraEnabled, let c = CameraMotion.shared.velocity() {
            x += c.0 * 5.0 * sens
            y += -c.1 * 5.0 * sens
        }

        return (x, y)
    }

    /// Human-readable list of the sources currently contributing, for the menu.
    func activeSources() -> [String] {
        let s = Settings.shared
        var out: [String] = ["scroll/pointer"]
        if s.lidEnabled && LidSensor.shared.present { out.append("accelerometer") }
        if s.cameraEnabled && CameraMotion.shared.running { out.append("camera") }
        return out
    }
}
