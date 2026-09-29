// Composes MenoMap App Store frames (Docs/MenoMap_Visual_Identity.md): warm stone ground, faint ember contours,
// a serif headline with the *accent* words in ember, and the real UI below with rounded corners and a soft shadow.
// 6.9" master: 1320 × 2868 PNG, RGB, no alpha.
//
// Usage: swift Tools/make_store_screenshots.swift <frames.json> <rawDir> <outDir>
//   frames.json: {"<lang>": {"headlines": {"1": "Log a hot flash in *one tap*.", …}, "rtl": false}}
//   rawDir/<lang>/01.png … 09.png  →  outDir/<lang>/01.png … 09.png

import AppKit
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

let args = CommandLine.arguments
guard args.count >= 4 else { print("usage: make_store_screenshots.swift <frames.json> <rawDir> <outDir>"); exit(1) }
let rawDir = URL(fileURLWithPath: args[2]), outDir = URL(fileURLWithPath: args[3])
struct Frame: Decodable { let headlines: [String: String]; let rtl: Bool? }
let frames = try JSONDecoder().decode([String: Frame].self, from: Data(contentsOf: URL(fileURLWithPath: args[1])))

let W = 1320, H = 2868
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
func rgb(_ h: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((h >> 16) & 255) / 255, green: CGFloat((h >> 8) & 255) / 255, blue: CGFloat(h & 255) / 255, alpha: a)
}
let ink = rgb(0x1E2524), ember = rgb(0xD4552A)

func serif(_ size: CGFloat) -> NSFont {
    let base = NSFont.systemFont(ofSize: size, weight: .semibold)
    return base.fontDescriptor.withDesign(.serif).flatMap { NSFont(descriptor: $0, size: size) } ?? base
}

/// "Log a hot flash in *one tap*." → attributed string with the starred words in ember.
func headline(_ text: String, size: CGFloat, rtl: Bool) -> NSAttributedString {
    let result = NSMutableAttributedString()
    let para = NSMutableParagraphStyle()
    para.alignment = .center
    para.lineBreakMode = .byWordWrapping
    para.lineHeightMultiple = 0.98
    para.baseWritingDirection = rtl ? .rightToLeft : .leftToRight
    for (i, piece) in text.components(separatedBy: "*").enumerated() where !piece.isEmpty {
        result.append(NSAttributedString(string: piece, attributes: [
            .font: serif(size), .foregroundColor: NSColor(cgColor: i % 2 == 1 ? ember : ink) ?? .black, .paragraphStyle: para,
            .kern: -0.5,
        ]))
    }
    return result
}

/// Largest size (≤ 124) at which the headline fits `box` in at most 3 lines.
func fitted(_ text: String, box: CGSize, rtl: Bool) -> (CTFramesetter, CGSize) {
    var size: CGFloat = 124
    while size > 60 {
        let fs = CTFramesetterCreateWithAttributedString(headline(text, size: size, rtl: rtl))
        let path = CGPath(rect: CGRect(origin: .zero, size: CGSize(width: box.width, height: 10_000)), transform: nil)
        let frame = CTFramesetterCreateFrame(fs, CFRange(), path, nil)
        let lines = (CTFrameGetLines(frame) as? [CTLine]) ?? []
        let need = CTFramesetterSuggestFrameSizeWithConstraints(fs, CFRange(), nil, CGSize(width: box.width, height: .greatestFiniteMagnitude), nil)
        if lines.count <= 3 && need.height <= box.height { return (fs, need) }
        size -= 4
    }
    let fs = CTFramesetterCreateWithAttributedString(headline(text, size: 60, rtl: rtl))
    return (fs, CTFramesetterSuggestFrameSizeWithConstraints(fs, CFRange(), nil, CGSize(width: box.width, height: .greatestFiniteMagnitude), nil))
}

func contour(_ r: CGFloat, seed: Double, cx: CGFloat, cy: CGFloat) -> CGPath {
    let p = CGMutablePath()
    for k in 0...200 {
        let a = Double(k) / 200 * 2 * .pi
        let w = 1 + 0.06 * sin(3 * a + seed) + 0.035 * sin(5 * a - seed * 0.7)
        let pt = CGPoint(x: cx + CGFloat(cos(a) * w) * r, y: cy + CGFloat(sin(a) * w) * r * 0.9)
        k == 0 ? p.move(to: pt) : p.addLine(to: pt)
    }
    p.closeSubpath()
    return p
}

func loadImage(_ url: URL) -> CGImage? {
    guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(src, 0, nil)
}

func save(_ image: CGImage, _ url: URL) {
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
}

for (lang, frame) in frames.sorted(by: { $0.key < $1.key }) {
    let dir = outDir.appendingPathComponent(lang)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    for n in 1...9 {
        let key = String(n), file = String(format: "%02d.png", n)
        guard let text = frame.headlines[key], let shot = loadImage(rawDir.appendingPathComponent(lang).appendingPathComponent(file)) else { continue }
        let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        // Ground (CoreGraphics origin is bottom-left).
        let grad = CGGradient(colorsSpace: cs, colors: [rgb(0xF6F1EA), rgb(0xEFE6DA)] as CFArray, locations: [0, 1])!
        ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: CGFloat(H)), end: CGPoint(x: 0, y: 0), options: [])
        for i in 0..<6 {
            ctx.addPath(contour(CGFloat(760 - i * 110), seed: Double(i) * 0.8 + Double(n), cx: 1180, cy: CGFloat(H) - 260))
            ctx.setStrokeColor(rgb(0xD4552A, 0.07 + CGFloat(i) * 0.02))
            ctx.setLineWidth(3)
            ctx.strokePath()
        }
        // Headline block: top 150…700.
        let box = CGSize(width: 1140, height: 520)
        let (fs, need) = fitted(text, box: box, rtl: frame.rtl ?? false)
        let top: CGFloat = 170
        let rect = CGRect(x: (CGFloat(W) - box.width) / 2, y: CGFloat(H) - top - need.height, width: box.width, height: need.height + 4)
        CTFrameDraw(CTFramesetterCreateFrame(fs, CFRange(), CGPath(rect: rect, transform: nil), nil), ctx)
        // Device screenshot: 78% width, rounded, shadowed, bleeding off the bottom.
        let scale: CGFloat = 0.8
        let sw = CGFloat(shot.width) * scale * CGFloat(W) / CGFloat(shot.width), sh = sw * CGFloat(shot.height) / CGFloat(shot.width)
        let sx = (CGFloat(W) - sw) / 2
        let sy = CGFloat(H) - 190 - need.height - 90 - sh
        let card = CGRect(x: sx, y: sy, width: sw, height: sh)
        let rounded = CGPath(roundedRect: card, cornerWidth: 92, cornerHeight: 92, transform: nil)
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -24), blur: 70, color: rgb(0x1E2524, 0.22))
        ctx.addPath(rounded); ctx.setFillColor(rgb(0xFFFFFF)); ctx.fillPath()
        ctx.restoreGState()
        ctx.saveGState()
        ctx.addPath(rounded); ctx.clip()
        ctx.draw(shot, in: card)
        ctx.restoreGState()
        ctx.addPath(rounded); ctx.setStrokeColor(rgb(0x1E2524, 0.08)); ctx.setLineWidth(3); ctx.strokePath()
        save(ctx.makeImage()!, dir.appendingPathComponent(file))
    }
    print("composed \(lang)")
}
