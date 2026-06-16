import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let overlays = OverlayManager()
    private var settingsController: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Settings.shared.register()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            if #available(macOS 11.0, *),
               let img = NSImage(systemSymbolName: "waveform.path.ecg", accessibilityDescription: "MotionSick") {
                button.image = img
            } else {
                button.title = "〰︎"
            }
        }

        MotionInput.shared.install()   // scroll/pointer flow
        LidSensor.shared.start()       // device accelerometer (vehicle motion)
        updateCamera()                 // optical flow, if enabled
        rebuildMenu()
        overlays.rebuild()

        NotificationCenter.default.addObserver(self, selector: #selector(settingsChanged),
                                               name: Settings.didChange, object: nil)
    }

    @objc private func settingsChanged() {
        updateCamera()
        rebuildMenu()
    }

    /// Run the camera only when a fusing mode is active and the user allows it.
    private func updateCamera() {
        let s = Settings.shared
        let wantCamera = s.cameraEnabled && s.overlayEnabled && (s.mode == .combo || s.mode == .sensor)
        if wantCamera { CameraMotion.shared.start() } else { CameraMotion.shared.stop() }
    }

    @objc private func rebuildMenu() {
        let menu = NSMenu()
        let header = NSMenuItem(title: "MotionSick", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        let toggle = NSMenuItem(title: "Show Overlay", action: #selector(toggleOverlay), keyEquivalent: "o")
        toggle.target = self
        toggle.state = Settings.shared.overlayEnabled ? .on : .off
        menu.addItem(toggle)

        let sources = MotionFusion.shared.activeSources().joined(separator: ", ")
        let sensorInfo = NSMenuItem(title: "Sources: " + sources, action: nil, keyEquivalent: "")
        sensorInfo.isEnabled = false
        menu.addItem(sensorInfo)

        menu.addItem(.separator())

        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        let quit = NSMenuItem(title: "Quit MotionSick", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)

        statusItem.menu = menu
    }

    @objc private func toggleOverlay() {
        Settings.shared.overlayEnabled.toggle()
    }

    @objc private func openSettings() {
        // Rebuild fresh every time so the panel always reflects the current
        // settings (e.g. after toggling the overlay from the menu) and never
        // shows a stale control state.
        settingsController?.close()
        settingsController = SettingsWindowController()
        NSApp.activate(ignoringOtherApps: true)
        settingsController?.showWindow(nil)
        settingsController?.window?.makeKeyAndOrderFront(nil)
    }
}

private extension Settings {
    func register() { _ = Settings.shared } // force init / defaults registration
}
