import Foundation
import IOKit
import IOKit.hid

/// Reads the Mac's built-in motion HID sensors (the Apple Silicon lid-angle
/// accelerometer / orientation sensors live on HID usage page 0x20).
///
/// This is the most relevant real source in a train or car: the whole laptop
/// accelerates with the vehicle, so braking, turns and lateral sway tilt the
/// apparent-gravity vector and show up as changes here. We track the rate of
/// change (a "sway" signal) rather than the absolute value.
final class LidSensor {
    static let shared = LidSensor()

    private var manager: IOHIDManager?
    private(set) var present = false
    private let lock = NSLock()
    private var lastValues: [UInt32: Double] = [:]
    private var swayX = 0.0, swayY = 0.0

    func start() {
        let mgr = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        // Match HID sensor page (0x20) — covers lid-angle / orientation accel.
        let match: [String: Any] = [kIOHIDDeviceUsagePageKey: 0x20]
        IOHIDManagerSetDeviceMatching(mgr, match as CFDictionary)

        let ctx = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterInputValueCallback(mgr, { context, _, _, value in
            guard let context = context else { return }
            let me = Unmanaged<LidSensor>.fromOpaque(context).takeUnretainedValue()
            me.handle(value)
        }, ctx)

        IOHIDManagerScheduleWithRunLoop(mgr, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        let r = IOHIDManagerOpen(mgr, IOOptionBits(kIOHIDOptionsTypeNone))
        // Open can succeed with zero matching devices (e.g. Apple Silicon, where
        // the lid sensor isn't exposed). Only claim presence if a real device
        // matched — otherwise we'd advertise a source that does nothing.
        let devs = (IOHIDManagerCopyDevices(mgr) as? Set<IOHIDDevice>)?.count ?? 0
        present = (r == kIOReturnSuccess) && devs > 0
        manager = mgr
    }

    private func handle(_ value: IOHIDValue) {
        let element = IOHIDValueGetElement(value)
        let usage = IOHIDElementGetUsage(element)
        let v = Double(IOHIDValueGetIntegerValue(value))
        lock.lock()
        if let prev = lastValues[usage] {
            let delta = v - prev
            // First changing axis drives X (lateral), a second drives Y.
            if usage % 2 == 0 {
                swayX = swayX * 0.6 + delta * 0.4
            } else {
                swayY = swayY * 0.6 + delta * 0.4
            }
        }
        lastValues[usage] = v
        lock.unlock()
    }

    /// Rate-of-change "sway" vector from the device accelerometer, then decay.
    /// Call once per physics tick. nil when no sensor is present.
    func velocity() -> (Double, Double)? {
        guard present else { return nil }
        lock.lock()
        let r = (swayX, swayY)
        swayX *= 0.82; swayY *= 0.82
        lock.unlock()
        return r
    }
}
