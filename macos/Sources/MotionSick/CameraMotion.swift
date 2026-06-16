import AVFoundation
import CoreVideo

/// Real-world motion from the camera via global optical flow (Lucas-Kanade over
/// a coarse grid). Frames are processed on-device, never recorded.
///
/// In a vehicle the front camera mostly sees the cabin (which moves with you),
/// so this mainly captures bumps and body sway — it's a secondary fused source,
/// while the device accelerometer carries the steady vehicle motion.
final class CameraMotion: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    static let shared = CameraMotion()

    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "motionsick.camera")
    private let lock = NSLock()
    private var prev: [Float] = []
    private var gw = 0, gh = 0
    private var fx = 0.0, fy = 0.0
    private(set) var running = false
    private(set) var authorized = false

    func start() {
        guard !running else { return }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configure()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] ok in
                if ok { DispatchQueue.main.async { self?.configure() } }
            }
        default:
            authorized = false
        }
    }

    func stop() {
        guard running else { return }
        session.stopRunning()
        running = false
        lock.lock(); fx = 0; fy = 0; prev = []; lock.unlock()
    }

    private func configure() {
        authorized = true
        guard !running else { return }
        session.beginConfiguration()
        if session.canSetSessionPreset(.low) { session.sessionPreset = .low }
        guard let dev = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: dev),
              session.canAddInput(input) else {
            session.commitConfiguration(); return
        }
        session.addInput(input)
        let out = AVCaptureVideoDataOutput()
        out.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        out.alwaysDiscardsLateVideoFrames = true
        out.setSampleBufferDelegate(self, queue: queue)
        if session.canAddOutput(out) { session.addOutput(out) }
        session.commitConfiguration()
        session.startRunning()
        running = true
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pb = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        CVPixelBufferLockBaseAddress(pb, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pb, .readOnly) }
        let w = CVPixelBufferGetWidth(pb), h = CVPixelBufferGetHeight(pb)
        let bpr = CVPixelBufferGetBytesPerRow(pb)
        guard let base = CVPixelBufferGetBaseAddress(pb) else { return }
        let ptr = base.assumingMemoryBound(to: UInt8.self)

        let step = 6
        let cw = w / step, ch = h / step
        if cw < 4 || ch < 4 { return }
        var cur = [Float](repeating: 0, count: cw * ch)
        var i = 0
        for cy in 0..<ch {
            let yy = cy * step
            for cx in 0..<cw {
                let off = yy * bpr + cx * step * 4
                let b = Float(ptr[off]), g = Float(ptr[off + 1]), r = Float(ptr[off + 2])
                cur[i] = 0.114 * b + 0.587 * g + 0.299 * r
                i += 1
            }
        }

        if prev.count == cur.count && gw == cw && gh == ch {
            var sIxIt: Float = 0, sIyIt: Float = 0, sIxx: Float = 0, sIyy: Float = 0
            for yy in 1..<(ch - 1) {
                let rowBase = yy * cw
                for xx in 1..<(cw - 1) {
                    let idx = rowBase + xx
                    let ix = (cur[idx + 1] - cur[idx - 1]) * 0.5
                    let iy = (cur[idx + cw] - cur[idx - cw]) * 0.5
                    let it = cur[idx] - prev[idx]
                    sIxIt += ix * it; sIyIt += iy * it
                    sIxx += ix * ix; sIyy += iy * iy
                }
            }
            let eps: Float = 800
            let dx = Double(-sIxIt / (sIxx + eps))
            let dy = Double(-sIyIt / (sIyy + eps))
            lock.lock()
            fx = fx * 0.5 + dx * 0.5
            fy = fy * 0.5 + dy * 0.5
            lock.unlock()
        }
        prev = cur; gw = cw; gh = ch
    }

    /// Smoothed scene-motion velocity (image coords), or nil if not running.
    func velocity() -> (Double, Double)? {
        guard running else { return nil }
        lock.lock(); let r = (fx, fy); lock.unlock()
        return r
    }
}
