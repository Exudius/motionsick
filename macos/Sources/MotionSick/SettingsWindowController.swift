import AppKit

/// Programmatic AppKit settings window — no SwiftUI, so it builds and runs on
/// the full supported macOS range. Every control writes straight to
/// `Settings.shared`, which live-updates the overlay.
final class SettingsWindowController: NSWindowController {
    private let s = Settings.shared
    private weak var themePopup: NSPopUpButton?

    convenience init() {
        let win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 700),
                           styleMask: [.titled, .closable, .miniaturizable],
                           backing: .buffered, defer: false)
        win.title = "MotionSick"
        win.isReleasedWhenClosed = false
        self.init(window: win)
        buildUI()
        win.center()
    }

    private func buildUI() {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 18, left: 18, bottom: 18, right: 18)
        stack.translatesAutoresizingMaskIntoConstraints = false

        // Header
        stack.addArrangedSubview(title("MotionSick", size: 17, bold: true))
        let sensorState = MotionSensor.shared.available
            ? "Hardware motion sensor detected (\(MotionSensor.shared.modelName))."
            : "No hardware motion sensor — using simulated cues."
        stack.addArrangedSubview(subtitle("Peripheral motion cues to ease motion sickness.\n" + sensorState))

        stack.addArrangedSubview(separator())

        // Master enable
        stack.addArrangedSubview(checkbox("Show motion-cue overlay", get: { self.s.overlayEnabled },
                                          set: { self.s.overlayEnabled = $0 }))

        // Mode
        stack.addArrangedSubview(title("Motion mode", size: 12, bold: true))
        let modePopup = NSPopUpButton(frame: .zero, pullsDown: false)
        for m in Settings.Mode.allCases {
            modePopup.addItem(withTitle: m.label)
            if m == .sensor && !MotionSensor.shared.available {
                modePopup.lastItem?.isEnabled = false
            }
        }
        modePopup.selectItem(at: Settings.Mode.allCases.firstIndex(of: s.mode) ?? 0)
        modePopup.target = self
        modePopup.action = #selector(modeChanged(_:))
        stack.addArrangedSubview(modePopup)

        // Fused real-motion sources (Combo mode).
        stack.addArrangedSubview(title("Real-motion sources (Combo)", size: 12, bold: true))
        let lidLabel = "Device accelerometer" + (LidSensor.shared.present ? " ✓" : " (not found)")
        stack.addArrangedSubview(checkbox(lidLabel, get: { self.s.lidEnabled }, set: { self.s.lidEnabled = $0 }))
        stack.addArrangedSubview(checkbox("Camera optical flow", get: { self.s.cameraEnabled }, set: { self.s.cameraEnabled = $0 }))
        stack.addArrangedSubview(checkbox("React to scrolling", get: { self.s.scrollEnabled }, set: { self.s.scrollEnabled = $0 }))
        stack.addArrangedSubview(checkbox("Follow mouse pointer", get: { self.s.pointerEnabled }, set: { self.s.pointerEnabled = $0 }))
        let note = subtitle("In a train/car the accelerometer carries real vehicle motion; the camera adds bumps & sway. Turn off scrolling and pointer to base cues on real motion only.")
        stack.addArrangedSubview(note)

        stack.addArrangedSubview(separator())

        // Sliders
        stack.addArrangedSubview(slider("Intensity", min: 0, max: 1,
            info: "How far the dots travel for a given motion. Higher = stronger, more noticeable cue.",
            get: { self.s.intensity }, set: { self.s.intensity = $0 }))
        stack.addArrangedSubview(slider("Speed", min: 0, max: 1,
            info: "Pace of the Calm-mode drift and overall motion smoothing. Lower = slower, gentler.",
            get: { self.s.speed }, set: { self.s.speed = $0 }))
        stack.addArrangedSubview(slider("Motion sensitivity", min: 0, max: 1,
            info: "Amplifies the camera / accelerometer signal. Raise it if real motion barely moves the dots.",
            get: { self.s.sensorGain }, set: { self.s.sensorGain = $0 }))
        stack.addArrangedSubview(slider("Dot size", min: 2, max: 20,
            info: "Diameter of each dot, in pixels.",
            get: { self.s.dotSize }, set: { self.s.dotSize = $0 }))
        stack.addArrangedSubview(slider("Spacing", min: 24, max: 160,
            info: "Gap between dots along the edges. Larger = fewer, more spread-out dots.",
            get: { self.s.spacing }, set: { self.s.spacing = $0 }))
        stack.addArrangedSubview(slider("Opacity", min: 0.05, max: 1,
            info: "How solid the dots appear. Lower = more transparent and subtle.",
            get: { self.s.opacity }, set: { self.s.opacity = $0 }))
        stack.addArrangedSubview(checkbox("Fade & swell with motion (Apple-style)",
            get: { self.s.fadeWithMotion }, set: { self.s.fadeWithMotion = $0 }))

        stack.addArrangedSubview(separator())

        // Edges
        stack.addArrangedSubview(title("Active edges", size: 12, bold: true))
        let edges = NSStackView()
        edges.orientation = .horizontal
        edges.spacing = 10
        edges.addArrangedSubview(checkbox("Top", get: { self.s.edgeTop }, set: { self.s.edgeTop = $0 }))
        edges.addArrangedSubview(checkbox("Bottom", get: { self.s.edgeBottom }, set: { self.s.edgeBottom = $0 }))
        edges.addArrangedSubview(checkbox("Left", get: { self.s.edgeLeft }, set: { self.s.edgeLeft = $0 }))
        edges.addArrangedSubview(checkbox("Right", get: { self.s.edgeRight }, set: { self.s.edgeRight = $0 }))
        stack.addArrangedSubview(edges)

        // Theme
        stack.addArrangedSubview(title("Dot color", size: 12, bold: true))
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 10
        let pop = NSPopUpButton(frame: .zero, pullsDown: false)
        for t in Settings.Theme.allCases { pop.addItem(withTitle: t.label) }
        pop.selectItem(at: Settings.Theme.allCases.firstIndex(of: s.theme) ?? 0)
        pop.target = self
        pop.action = #selector(themeChanged(_:))
        themePopup = pop
        row.addArrangedSubview(pop)

        let well = NSColorWell()
        well.color = s.customColor
        well.translatesAutoresizingMaskIntoConstraints = false
        well.widthAnchor.constraint(equalToConstant: 54).isActive = true
        well.heightAnchor.constraint(equalToConstant: 24).isActive = true
        let wellHandler = ActionHandler { [weak self, weak well] in
            guard let self = self, let well = well else { return }
            self.s.customColor = well.color
            self.s.theme = .custom                 // pick a colour → switch to Custom
            self.themePopup?.selectItem(at: Settings.Theme.allCases.firstIndex(of: .custom) ?? 0)
        }
        well.target = wellHandler
        well.action = #selector(ActionHandler.fire)
        objc_setAssociatedObject(well, Unmanaged.passUnretained(well).toOpaque(), wellHandler, .OBJC_ASSOCIATION_RETAIN)
        row.addArrangedSubview(well)
        stack.addArrangedSubview(row)
        stack.addArrangedSubview(subtitle("Pick \"Custom\" (or use the swatch) for any dot colour you like."))

        stack.addArrangedSubview(separator())

        // Comfort tint
        stack.addArrangedSubview(checkbox("Comfort tint (warm screen wash)", get: { self.s.tintEnabled }, set: { self.s.tintEnabled = $0 }))
        stack.addArrangedSubview(slider("Tint opacity", min: 0, max: 0.4,
            info: "Strength of the warm wash laid over the whole screen to soften glare.",
            get: { self.s.tintOpacity }, set: { self.s.tintOpacity = $0 }))
        stack.addArrangedSubview(slider("Tint warmth", min: 0, max: 1,
            info: "Colour of the wash, from cool amber to deep warm red.",
            get: { self.s.tintWarmth }, set: { self.s.tintWarmth = $0 }))

        stack.addArrangedSubview(separator())

        // Buttons
        let buttons = NSStackView()
        buttons.orientation = .horizontal
        buttons.spacing = 10
        let calibrate = NSButton(title: "Calibrate sensor", target: self, action: #selector(calibrateTapped))
        calibrate.isEnabled = MotionSensor.shared.available
        let reset = NSButton(title: "Reset defaults", target: self, action: #selector(resetTapped))
        buttons.addArrangedSubview(calibrate)
        buttons.addArrangedSubview(reset)
        stack.addArrangedSubview(buttons)

        // Flipped document inside a scroll view so the (now tall) panel scrolls
        // and still fits small laptop screens.
        let doc = FlippedView()
        doc.translatesAutoresizingMaskIntoConstraints = false
        doc.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: doc.topAnchor),
            stack.leadingAnchor.constraint(equalTo: doc.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: doc.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: doc.bottomAnchor),
            doc.widthAnchor.constraint(equalToConstant: 380),
        ])
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.autohidesScrollers = true
        scroll.documentView = doc
        window?.contentView = scroll
    }

    // MARK: control builders

    private func title(_ text: String, size: CGFloat, bold: Bool) -> NSTextField {
        let t = NSTextField(labelWithString: text)
        t.font = bold ? .boldSystemFont(ofSize: size) : .systemFont(ofSize: size)
        return t
    }

    private func subtitle(_ text: String) -> NSTextField {
        let t = NSTextField(wrappingLabelWithString: text)
        t.font = .systemFont(ofSize: 11)
        t.textColor = .secondaryLabelColor
        t.preferredMaxLayoutWidth = 344
        return t
    }

    private func separator() -> NSView {
        let v = NSBox()
        v.boxType = .separator
        v.translatesAutoresizingMaskIntoConstraints = false
        v.widthAnchor.constraint(equalToConstant: 344).isActive = true
        return v
    }

    private func checkbox(_ label: String, get: @escaping () -> Bool, set: @escaping (Bool) -> Void) -> NSButton {
        let b = NSButton(checkboxWithTitle: label, target: nil, action: nil)
        b.state = get() ? .on : .off
        let handler = ActionHandler { [weak b] in set(b?.state == .on) }
        b.target = handler
        b.action = #selector(ActionHandler.fire)
        objc_setAssociatedObject(b, Unmanaged.passUnretained(b).toOpaque(), handler, .OBJC_ASSOCIATION_RETAIN)
        return b
    }

    private func slider(_ label: String, min lo: Double, max hi: Double, info: String = "",
                        get: @escaping () -> Double, set: @escaping (Double) -> Void) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 8
        let name = NSTextField(labelWithString: label)
        name.font = .systemFont(ofSize: 11)
        name.translatesAutoresizingMaskIntoConstraints = false
        name.widthAnchor.constraint(equalToConstant: 92).isActive = true

        let slider = NSSlider(value: get(), minValue: lo, maxValue: hi, target: nil, action: nil)
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.widthAnchor.constraint(equalToConstant: 232).isActive = true
        let handler = ActionHandler { [weak slider] in if let slider = slider { set(slider.doubleValue) } }
        slider.target = handler
        slider.action = #selector(ActionHandler.fire)
        objc_setAssociatedObject(slider, Unmanaged.passUnretained(slider).toOpaque(), handler, .OBJC_ASSOCIATION_RETAIN)

        row.addArrangedSubview(name)
        row.addArrangedSubview(slider)

        // Stack the slider row above a small explanatory caption.
        let container = NSStackView()
        container.orientation = .vertical
        container.alignment = .leading
        container.spacing = 1
        container.addArrangedSubview(row)
        if !info.isEmpty {
            slider.toolTip = info
            let cap = NSTextField(wrappingLabelWithString: info)
            cap.font = .systemFont(ofSize: 10)
            cap.textColor = .tertiaryLabelColor
            cap.preferredMaxLayoutWidth = 332
            container.addArrangedSubview(cap)
        }
        return container
    }

    // MARK: actions

    @objc private func modeChanged(_ sender: NSPopUpButton) {
        let idx = sender.indexOfSelectedItem
        if idx >= 0 && idx < Settings.Mode.allCases.count { s.mode = Settings.Mode.allCases[idx] }
    }
    @objc private func themeChanged(_ sender: NSPopUpButton) {
        let idx = sender.indexOfSelectedItem
        if idx >= 0 && idx < Settings.Theme.allCases.count { s.theme = Settings.Theme.allCases[idx] }
    }
    @objc private func calibrateTapped() { MotionSensor.shared.calibrate() }
    @objc private func resetTapped() {
        s.resetToDefaults()
        window?.contentView = nil
        buildUI()
    }
}

/// Top-down coordinate container so scroll-view content starts at the top.
final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

/// Tiny target object so closures can back AppKit controls without subclassing.
final class ActionHandler: NSObject {
    private let block: () -> Void
    init(_ block: @escaping () -> Void) { self.block = block }
    @objc func fire() { block() }
}
