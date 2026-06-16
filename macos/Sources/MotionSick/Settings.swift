import AppKit

/// App-wide settings, persisted to UserDefaults. Pure AppKit (no SwiftUI) so the
/// binary stays compatible from old macOS (10.14+) to the very latest.
/// Any mutation persists immediately and posts `.didChange` so the overlay
/// live-updates without a restart.
final class Settings {
    static let shared = Settings()
    static let didChange = Notification.Name("MotionSickSettingsDidChange")

    enum Mode: String, CaseIterable {
        case combo    // fuse every available real source (camera + lid + scroll)
        case sensor   // real accelerometer (Intel MacBook Sudden Motion Sensor)
        case calm     // slow, predictable peripheral bob — a steady "horizon"
        case reactive // dots flow with pointer/scroll motion
        case fixed    // static dots — a fixed stable reference frame
        var label: String {
            switch self {
            case .combo:    return "Combo (fuse all real sensors)"
            case .sensor:   return "Sensor (Intel SMS only)"
            case .calm:     return "Calm (gentle horizon)"
            case .reactive: return "Reactive (scroll / pointer)"
            case .fixed:    return "Fixed (still reference)"
            }
        }
    }

    enum Theme: String, CaseIterable {
        case amber, white, cyan, custom
        var label: String { rawValue.capitalized }
        var color: NSColor {
            switch self {
            case .amber:  return NSColor(calibratedRed: 1.0, green: 0.80, blue: 0.42, alpha: 1)
            case .white:  return NSColor(calibratedWhite: 0.95, alpha: 1)
            case .cyan:   return NSColor(calibratedRed: 0.55, green: 0.90, blue: 1.0, alpha: 1)
            case .custom: return NSColor(calibratedRed: 1.0, green: 0.80, blue: 0.42, alpha: 1)
            }
        }
    }

    private let d = UserDefaults.standard

    private init() {
        d.register(defaults: [
            "overlayEnabled": true,
            "mode": Mode.combo.rawValue,
            "intensity": 0.75,
            "speed": 0.5,
            "dotSize": 9.0,
            "spacing": 74.0,
            "opacity": 0.7,
            "edgeTop": true, "edgeBottom": true, "edgeLeft": true, "edgeRight": true,
            "theme": Theme.amber.rawValue,
            "tintEnabled": false,
            "tintOpacity": 0.10,
            "tintWarmth": 0.6,
            "sensorGain": 0.7,
            "cameraEnabled": true,
            "lidEnabled": true,
            "pointerEnabled": true,
            "scrollEnabled": true,
            "fadeWithMotion": true,
            "ccR": 1.0, "ccG": 0.80, "ccB": 0.42,
        ])
    }

    private func change(_ key: String, _ value: Any) {
        d.set(value, forKey: key)
        NotificationCenter.default.post(name: Settings.didChange, object: nil)
    }

    var overlayEnabled: Bool { get { d.bool(forKey: "overlayEnabled") } set { change("overlayEnabled", newValue) } }
    var mode: Mode { get { Mode(rawValue: d.string(forKey: "mode") ?? "") ?? .calm } set { change("mode", newValue.rawValue) } }
    var theme: Theme { get { Theme(rawValue: d.string(forKey: "theme") ?? "") ?? .amber } set { change("theme", newValue.rawValue) } }

    var intensity: Double { get { d.double(forKey: "intensity") } set { change("intensity", newValue) } }
    var speed: Double { get { d.double(forKey: "speed") } set { change("speed", newValue) } }
    var dotSize: Double { get { d.double(forKey: "dotSize") } set { change("dotSize", newValue) } }
    var spacing: Double { get { d.double(forKey: "spacing") } set { change("spacing", newValue) } }
    var opacity: Double { get { d.double(forKey: "opacity") } set { change("opacity", newValue) } }
    var sensorGain: Double { get { d.double(forKey: "sensorGain") } set { change("sensorGain", newValue) } }
    var cameraEnabled: Bool { get { d.bool(forKey: "cameraEnabled") } set { change("cameraEnabled", newValue) } }
    var lidEnabled: Bool { get { d.bool(forKey: "lidEnabled") } set { change("lidEnabled", newValue) } }
    var pointerEnabled: Bool { get { d.bool(forKey: "pointerEnabled") } set { change("pointerEnabled", newValue) } }
    var scrollEnabled: Bool { get { d.bool(forKey: "scrollEnabled") } set { change("scrollEnabled", newValue) } }
    var fadeWithMotion: Bool { get { d.bool(forKey: "fadeWithMotion") } set { change("fadeWithMotion", newValue) } }

    /// User-picked dot colour, used when `theme == .custom`.
    var customColor: NSColor {
        get {
            NSColor(calibratedRed: CGFloat(d.double(forKey: "ccR")),
                    green: CGFloat(d.double(forKey: "ccG")),
                    blue: CGFloat(d.double(forKey: "ccB")), alpha: 1)
        }
        set {
            let c = newValue.usingColorSpace(.deviceRGB) ?? newValue
            d.set(Double(c.redComponent), forKey: "ccR")
            d.set(Double(c.greenComponent), forKey: "ccG")
            d.set(Double(c.blueComponent), forKey: "ccB")
            NotificationCenter.default.post(name: Settings.didChange, object: nil)
        }
    }

    /// The colour actually used to draw dots (respects the Custom theme).
    var dotColor: NSColor { theme == .custom ? customColor : theme.color }

    var edgeTop: Bool { get { d.bool(forKey: "edgeTop") } set { change("edgeTop", newValue) } }
    var edgeBottom: Bool { get { d.bool(forKey: "edgeBottom") } set { change("edgeBottom", newValue) } }
    var edgeLeft: Bool { get { d.bool(forKey: "edgeLeft") } set { change("edgeLeft", newValue) } }
    var edgeRight: Bool { get { d.bool(forKey: "edgeRight") } set { change("edgeRight", newValue) } }

    var tintEnabled: Bool { get { d.bool(forKey: "tintEnabled") } set { change("tintEnabled", newValue) } }
    var tintOpacity: Double { get { d.double(forKey: "tintOpacity") } set { change("tintOpacity", newValue) } }
    var tintWarmth: Double { get { d.double(forKey: "tintWarmth") } set { change("tintWarmth", newValue) } }

    func resetToDefaults() {
        for k in ["overlayEnabled","mode","intensity","speed","dotSize","spacing","opacity",
                  "edgeTop","edgeBottom","edgeLeft","edgeRight","theme","tintEnabled",
                  "tintOpacity","tintWarmth","sensorGain","cameraEnabled","lidEnabled",
                  "pointerEnabled","scrollEnabled","fadeWithMotion","ccR","ccG","ccB"] {
            d.removeObject(forKey: k)
        }
        NotificationCenter.default.post(name: Settings.didChange, object: nil)
    }
}
