import Foundation
import IOKit

/// Reads the Apple "Sudden Motion Sensor" (SMS) accelerometer that ships in
/// Intel MacBook / MacBook Pro / MacBook Air models, via IOKit.
///
/// This is the same class of hardware Apple uses for device-motion features.
/// Apple Silicon Macs and desktops expose no such sensor — `available` is then
/// false and the app transparently falls back to the simulated cue modes.
///
/// Uses only IOKit calls available since macOS 10.5, so it stays compatible
/// across the whole supported OS range.
final class MotionSensor {
    static let shared = MotionSensor()

    private var connection: io_connect_t = 0
    private var selector: Int32 = 5          // SMCMotionSensor struct selector
    private(set) var available = false
    private(set) var modelName = "none"

    // Calibration baseline (rest orientation) + smoothed motion estimate.
    private var baseX = 0.0, baseY = 0.0, baseZ = 0.0
    private var haveBaseline = false
    private var smoothX = 0.0, smoothY = 0.0

    private init() {
        available = openSensor()
        if available {
            // Establish an initial rest baseline from the first reading.
            if let r = readRaw() {
                baseX = r.0; baseY = r.1; baseZ = r.2; haveBaseline = true
            }
        }
    }

    // Try the known SMS service names across model generations.
    private func openSensor() -> Bool {
        let candidates = ["SMCMotionSensor", "PMUMotionSensor", "IOI2CMotionSensor"]
        let sel: [String: Int32] = ["SMCMotionSensor": 5, "PMUMotionSensor": 21, "IOI2CMotionSensor": 21]
        for name in candidates {
            let service = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching(name))
            if service == 0 { continue }
            defer { IOObjectRelease(service) }
            var conn: io_connect_t = 0
            let kr = IOServiceOpen(service, mach_task_self_, 0, &conn)
            if kr == KERN_SUCCESS {
                connection = conn
                selector = sel[name] ?? 5
                modelName = name
                // Validate we can actually read something.
                if readRaw() != nil { return true }
                IOServiceClose(connection)
                connection = 0
            }
        }
        return false
    }

    /// Raw accelerometer triple (device units, roughly proportional to g).
    private func readRaw() -> (Double, Double, Double)? {
        guard connection != 0 else { return nil }
        var input = [Int8](repeating: 0, count: 40)
        var output = [Int8](repeating: 0, count: 40)
        var outputSize = size_t(output.count)
        let kr = IOConnectCallStructMethod(connection, UInt32(selector),
                                           &input, input.count,
                                           &output, &outputSize)
        guard kr == KERN_SUCCESS else { return nil }
        // The first three int16 little-endian words are x, y, z.
        func word(_ i: Int) -> Double {
            let lo = Int(UInt8(bitPattern: output[i]))
            let hi = Int(Int8(output[i + 1]))      // signed high byte
            return Double((hi << 8) | lo)
        }
        return (word(0), word(2), word(4))
    }

    /// Capture the current orientation as the rest baseline ("zero it out").
    func calibrate() {
        if let r = readRaw() {
            baseX = r.0; baseY = r.1; baseZ = r.2
            haveBaseline = true
            smoothX = 0; smoothY = 0
        }
    }

    /// Smoothed horizontal-plane motion relative to the calibrated rest pose.
    /// Returns nil when no sensor is present. Values are normalized-ish; callers
    /// apply their own gain. X = lateral (left/right), Y = longitudinal.
    func motion2D() -> (Double, Double)? {
        guard available, let r = readRaw() else { return nil }
        if !haveBaseline { baseX = r.0; baseY = r.1; baseZ = r.2; haveBaseline = true }
        let dx = (r.0 - baseX) / 256.0   // ~256 units per g on most SMS parts
        let dy = (r.1 - baseY) / 256.0
        smoothX = smoothX * 0.80 + dx * 0.20
        smoothY = smoothY * 0.80 + dy * 0.20
        return (smoothX, smoothY)
    }
}
