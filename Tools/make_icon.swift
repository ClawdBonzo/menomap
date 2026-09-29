// Renders the MenoMap mark (Docs/MenoMap_Visual_Identity.md → Icon): filled topographic contour bands,
// ember heat stepping inward to a teal calm core, on warm stone.
//
// Usage:  swift Tools/make_icon.swift <default|dark|tinted> <output.png> [pixelWidth]
// App Store icons carry no alpha channel.

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let args = CommandLine.arguments
guard args.count >= 3 else { print("usage: swift make_icon.swift <default|dark|tinted> <out.png> [px]"); exit(1) }
let variant = args[1]
let out = URL(fileURLWithPath: args[2])
let px = args.count > 3 ? (Int(args[3]) ?? 1024) : 1024
let s = CGFloat(px) / 1024

guard let cs = CGColorSpace(name: CGColorSpace.sRGB),
      let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                          bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { exit(1) }

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

func mix(_ a: UInt32, _ b: UInt32, _ t: CGFloat) -> CGColor {
    func c(_ h: UInt32, _ sh: UInt32) -> CGFloat { CGFloat((h >> sh) & 0xFF) / 255 }
    return CGColor(srgbRed: c(a, 16) + (c(b, 16) - c(a, 16)) * t, green: c(a, 8) + (c(b, 8) - c(a, 8)) * t,
                   blue: c(a, 0) + (c(b, 0) - c(a, 0)) * t, alpha: 1)
}

let ground: UInt32, ember: UInt32, teal: UInt32
switch variant {
case "dark": (ground, ember, teal) = (0x151311, 0xF07A4C, 0x52B8AE)
case "tinted": (ground, ember, teal) = (0x000000, 0xFFFFFF, 0xFFFFFF)
default: (ground, ember, teal) = (0xF3EEE7, 0xD4552A, 0x0D6B66)
}

ctx.translateBy(x: 0, y: CGFloat(px))
ctx.scaleBy(x: s, y: -s)
ctx.setFillColor(rgb(ground))
ctx.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))

/// Irregular closed contour around (cx, cy).
func contour(_ r: CGFloat, seed: Double, cx: CGFloat = 540, cy: CGFloat = 548) -> CGPath {
    let p = CGMutablePath()
    let steps = 240
    for k in 0...steps {
        let a = Double(k) / Double(steps) * 2 * .pi
        let w = 1 + 0.055 * sin(3 * a + seed) + 0.035 * sin(5 * a - seed * 0.7) + 0.02 * sin(2 * a + seed * 1.3)
        let pt = CGPoint(x: cx + CGFloat(cos(a) * w) * r * 1.06, y: cy + CGFloat(sin(a) * w) * r * 0.94)
        k == 0 ? p.move(to: pt) : p.addLine(to: pt)
    }
    p.closeSubpath()
    return p
}

// Bands from outside in: ember at stepped strength (mixed over the ground so there's no alpha).
let radii: [CGFloat] = [470, 392, 318, 250, 188]
let strengths: [CGFloat] = [0.14, 0.30, 0.50, 0.72, 0.94]
for (i, r) in radii.enumerated() {
    let path = contour(r, seed: Double(i) * 0.9 + 0.4, cx: 540 - CGFloat(i) * 6, cy: 548 - CGFloat(i) * 4)
    ctx.addPath(path)
    ctx.setFillColor(variant == "tinted" ? mix(ground, ember, strengths[i] * 0.9) : mix(ground, ember, strengths[i]))
    ctx.fillPath()
}
// Calm core: teal, with a hairline ring of ground around it.
let core = contour(118, seed: 2.2, cx: 512, cy: 530)
ctx.addPath(core)
ctx.setStrokeColor(rgb(ground))
ctx.setLineWidth(22)
ctx.strokePath()
ctx.addPath(core)
ctx.setFillColor(rgb(teal))
ctx.fillPath()

guard let img = ctx.makeImage(),
      let dest = CGImageDestinationCreateWithURL(out as CFURL, UTType.png.identifier as CFString, 1, nil) else { exit(1) }
CGImageDestinationAddImage(dest, img, nil)
CGImageDestinationFinalize(dest)
print("wrote \(out.path)")
