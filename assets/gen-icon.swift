// Renders the MotionSick app icon at a given size to a PNG.
// Usage: swift gen-icon.swift <size> <out.png>
import AppKit
import CoreGraphics
import Foundation

let size = CGFloat(Int(CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "1024") ?? 1024)
let outPath = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "icon.png"

let cs = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8,
                          bytesPerRow: 0, space: cs,
                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { exit(1) }

func col(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: r, green: g, blue: b, alpha: a)
}

// Squircle background with a soft inset (modern macOS look).
let inset = size * 0.06
let rect = CGRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
let radius = rect.width * 0.235
let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
ctx.addPath(path)
ctx.clip()

if let grad = CGGradient(colorsSpace: cs,
                         colors: [col(0.11, 0.17, 0.30), col(0.04, 0.06, 0.11)] as CFArray,
                         locations: [0, 1]) {
    ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: size), end: CGPoint(x: 0, y: 0), options: [])
}

// Amber palette.
let amber = col(1.0, 0.80, 0.42)
let amberGlow = col(1.0, 0.74, 0.30, 0.0)

func softDot(_ c: CGPoint, _ r: CGFloat, _ alpha: CGFloat) {
    if let g = CGGradient(colorsSpace: cs,
                          colors: [col(1.0, 0.80, 0.42, alpha), col(1.0, 0.80, 0.42, alpha), amberGlow] as CFArray,
                          locations: [0, 0.55, 1]) {
        ctx.drawRadialGradient(g, startCenter: c, startRadius: 0, endCenter: c, endRadius: r, options: [])
    }
}

// Peripheral ring of cue dots (the product, abstracted).
let m = size * 0.205
let dot = size * 0.028
let count = 7
let lo = m, hi = size - m
for i in 0..<count {
    let t = lo + (hi - lo) * CGFloat(i) / CGFloat(count - 1)
    softDot(CGPoint(x: t, y: hi), dot, 0.95)   // top
    softDot(CGPoint(x: t, y: lo), dot, 0.95)   // bottom
    softDot(CGPoint(x: lo, y: t), dot, 0.95)   // left
    softDot(CGPoint(x: hi, y: t), dot, 0.95)   // right
}

// Central motion wave (amber), giving the "alive" cue.
ctx.setStrokeColor(amber)
ctx.setLineWidth(size * 0.035)
ctx.setLineCap(.round)
let wave = CGMutablePath()
let midY = size * 0.5
let amp = size * 0.075
let x0 = size * 0.30, x1 = size * 0.70
var first = true
var x = x0
while x <= x1 {
    let p = (x - x0) / (x1 - x0)
    let y = midY + sin(p * .pi * 2) * amp
    if first { wave.move(to: CGPoint(x: x, y: y)); first = false }
    else { wave.addLine(to: CGPoint(x: x, y: y)) }
    x += size * 0.004
}
ctx.addPath(wave)
ctx.strokePath()

guard let img = ctx.makeImage() else { exit(1) }
let url = URL(fileURLWithPath: outPath)
guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else { exit(1) }
CGImageDestinationAddImage(dest, img, nil)
CGImageDestinationFinalize(dest)
