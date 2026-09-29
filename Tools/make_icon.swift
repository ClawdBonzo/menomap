// Renders the MenoMap mark (Docs/MenoMap_Visual_Identity.md → Icon), v2 (2026-09-29):
// an ember field with stone topographic contour lines closing in on a teal "calm core".
// Reads as a heat map at 60pt, never as a body shape, and pops on light and dark wallpapers.
//
// Usage:  swift Tools/make_icon.swift <default|dark|tinted> <output.png> [pixelWidth]

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
ctx.translateBy(x: 0, y: CGFloat(px))
ctx.scaleBy(x: s, y: -s)

func rgb(_ h: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((h >> 16) & 255) / 255, green: CGFloat((h >> 8) & 255) / 255, blue: CGFloat(h & 255) / 255, alpha: a)
}

/// Irregular closed contour; later (inner) rings drift toward the summit, like a real topo map.
func contour(_ r: CGFloat, seed: Double, cx: CGFloat, cy: CGFloat) -> CGPath {
    let p = CGMutablePath()
    for k in 0...240 {
        let a = Double(k) / 240 * 2 * .pi
        let w = 1 + 0.06 * sin(3 * a + seed) + 0.035 * sin(5 * a - seed * 0.7) + 0.02 * sin(2 * a + seed * 1.3)
        let pt = CGPoint(x: cx + CGFloat(cos(a) * w) * r * 1.04, y: cy + CGFloat(sin(a) * w) * r * 0.95)
        k == 0 ? p.move(to: pt) : p.addLine(to: pt)
    }
    p.closeSubpath()
    return p
}

let (top, mid, bottom, line, core, coreRing): (UInt32, UInt32, UInt32, UInt32, UInt32, UInt32)
switch variant {
case "dark": (top, mid, bottom, line, core, coreRing) = (0x2A1A12, 0x1A120E, 0x0E0A08, 0xF07A4C, 0x52B8AE, 0x1A120E)
case "tinted": (top, mid, bottom, line, core, coreRing) = (0x2A2A2A, 0x161616, 0x000000, 0xFFFFFF, 0xFFFFFF, 0x161616)
default: (top, mid, bottom, line, core, coreRing) = (0xF39463, 0xD4552A, 0xA3381A, 0xF3EEE7, 0x0D6B66, 0xF3EEE7)
}

let grad = CGGradient(colorsSpace: cs, colors: [rgb(top), rgb(mid), rgb(bottom)] as CFArray, locations: [0, 0.55, 1])!
ctx.drawLinearGradient(grad, start: CGPoint(x: 80, y: 0), end: CGPoint(x: 944, y: 1024), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])

// Contours from the outside in: spacing tightens and lines strengthen toward the summit.
let rings: [(r: CGFloat, alpha: CGFloat, width: CGFloat)] = [
    (560, 0.22, 12), (470, 0.32, 13), (385, 0.45, 14), (305, 0.62, 15), (235, 0.8, 16), (178, 0.95, 17),
]
for (i, ring) in rings.enumerated() {
    let t = CGFloat(i) / CGFloat(rings.count - 1)
    let path = contour(ring.r, seed: Double(i) * 0.85 + 0.4, cx: 540 - 60 * t, cy: 560 - 70 * t)
    ctx.addPath(path)
    ctx.setStrokeColor(rgb(line, ring.alpha))
    ctx.setLineWidth(ring.width)
    ctx.strokePath()
}

// Calm core: the teal summit.
let summit = contour(112, seed: 2.2, cx: 478, cy: 488)
ctx.addPath(summit)
ctx.setFillColor(rgb(core))
ctx.fillPath()
ctx.addPath(summit)
ctx.setStrokeColor(rgb(coreRing))
ctx.setLineWidth(14)
ctx.strokePath()

guard let img = ctx.makeImage(),
      let dest = CGImageDestinationCreateWithURL(out as CFURL, UTType.png.identifier as CFString, 1, nil) else { exit(1) }
CGImageDestinationAddImage(dest, img, nil)
CGImageDestinationFinalize(dest)
print("wrote \(out.path)")
