import AppKit

/// Creates and manages one transparent, click-through overlay window per screen,
/// and rebuilds them when the display configuration changes.
final class OverlayManager {
    private var windows: [NSWindow] = []
    private var views: [OverlayView] = []

    init() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(settingsChanged),
            name: Settings.didChange, object: nil)
    }

    func rebuild() {
        teardown()
        MotionEngine.shared.clearViews()
        for screen in NSScreen.screens {
            let win = NSWindow(contentRect: screen.frame,
                               styleMask: .borderless,
                               backing: .buffered,
                               defer: false)
            win.isOpaque = false
            win.backgroundColor = .clear
            win.hasShadow = false
            win.ignoresMouseEvents = true                 // fully click-through
            win.level = .screenSaver                       // floats above app windows
            win.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
            win.isReleasedWhenClosed = false

            let view = OverlayView(frame: NSRect(origin: .zero, size: screen.frame.size))
            win.contentView = view
            windows.append(win)
            views.append(view)
        }
        applyEnabledState()
    }

    private func applyEnabledState() {
        let on = Settings.shared.overlayEnabled
        for win in windows {
            if on { win.orderFrontRegardless() } else { win.orderOut(nil) }
        }
        if on { MotionEngine.shared.start() } else { MotionEngine.shared.stop() }
    }

    private func teardown() {
        MotionEngine.shared.stop()
        for win in windows { win.orderOut(nil) }
        windows.removeAll()
        views.removeAll()
    }

    @objc private func screensChanged() { rebuild() }
    @objc private func settingsChanged() {
        applyEnabledState()
        views.forEach { $0.needsDisplay = true }
    }
}
