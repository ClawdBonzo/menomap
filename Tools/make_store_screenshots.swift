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

/// Chinese and Japanese break between any two characters, which splits words ("夜の見|守り"). Group the text into
/// phrases (a word plus its trailing particles, katakana compounds, a number with its counter) and glue each phrase
/// with WORD JOINERs so CoreText can only break between phrases.
func phraseGluedPlain(_ text: String, lang: String) -> (String, Bool) {
    let ns = text as NSString, cf = text as CFString
    let tok = CFStringTokenizerCreate(nil, cf, CFRange(location: 0, length: ns.length), kCFStringTokenizerUnitWordBoundary,
                                      Locale(identifier: lang) as CFLocale)
    func all(_ s: String, _ ranges: [ClosedRange<UInt32>]) -> Bool {
        s.unicodeScalars.allSatisfy { u in ranges.contains { $0.contains(u.value) } }
    }
    let hiragana: [ClosedRange<UInt32>] = [0x3040...0x309F], katakana: [ClosedRange<UInt32>] = [0x30A0...0x30FF]
    var chunks: [String] = [], last = "", cursor = 0, firstJoins = false
    func attach(_ piece: String) { if chunks.isEmpty { chunks.append(piece) } else { chunks[chunks.count - 1] += piece } }
    while !CFStringTokenizerAdvanceToNextToken(tok).isEmpty {
        let r = CFStringTokenizerGetCurrentTokenRange(tok)
        if r.location > cursor { attach(ns.substring(with: NSRange(location: cursor, length: r.location - cursor))) }  // punctuation
        let t = ns.substring(with: NSRange(location: r.location, length: r.length))
        let particles: Set<String> = ["は", "が", "を", "に", "で", "と", "の", "へ", "も", "や", "から", "まで", "より", "ね", "よ", "か", "て", "た", "だ"]
        let cjkLast = !last.isEmpty && !all(last, [0x0020...0x024F])
        let joins = lang == "th" ? (last.last?.isNumber ?? false) : lang == "ja"
            ? (particles.contains(t) || (t.count == 1 && all(t, hiragana)) || (all(t, katakana) && all(last, katakana))
               || (last.last?.isNumber ?? false))
            : ((t.count == 1 && cjkLast) || (last.last?.isNumber ?? false))  // zh: keep 紅, 用 with their word
        if joins && chunks.isEmpty { firstJoins = true }
        if joins { attach(t) } else { chunks.append(t) }
        last = t
        cursor = r.location + r.length
    }
    if cursor < ns.length { attach(ns.substring(from: cursor)) }
    return (chunks.map { $0.map(String.init).joined(separator: "\u{2060}") }.joined(), firstJoins)
}

/// Accent spans (*夜间守护*) are key terms: in CJK keep a short one on a single line, and keep a particle that follows
/// it (*ワンタップ*で) attached.
func phraseGlued(_ text: String, lang: String) -> String {
    let wj = "\u{2060}"
    // Korean has spaces but CoreText also breaks between any two syllables (안면홍|조): break only at spaces.
    if lang == "ko" {
        // …and keep a short highlighted span (*밤 지킴이*) on one line.
        let spans = text.components(separatedBy: "*").enumerated()
            .map { i, p in i % 2 == 1 && p.count <= 10 ? p.replacingOccurrences(of: " ", with: "\u{00A0}") : p }.joined(separator: "*")
        return spans.components(separatedBy: " ").map { $0.map(String.init).joined(separator: wj) }.joined(separator: " ")
    }
    // Thai has no spaces either: glue each word so "Apple Watc|h" and mid-word breaks can't happen.
    guard lang == "ja" || lang.hasPrefix("zh") || lang == "th" else { return text }
    return text.components(separatedBy: "*").enumerated().map { i, piece -> String in
        if i % 2 == 1 && piece.count <= 8 { return piece.map(String.init).joined(separator: wj) }
        let (glued, firstJoins) = phraseGluedPlain(piece, lang: lang)
        return i > 0 && firstJoins ? wj + glued : glued
    }.joined(separator: "*")
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

/// A layout is acceptable when every line break is a real one (in spaced scripts at a space or hyphen, never inside a
/// word like "залишають|ся"; in CJK and Thai never at a WORD JOINER, which means CoreText had to force it) and the last
/// line isn't a widow: a lone short word ("tap.") or, in scripts without spaces, a single character ("用。").
func goodBreaks(_ lines: [CTLine], in text: NSAttributedString) -> Bool {
    let s = text.string as NSString
    let wj: unichar = 0x2060
    func has(_ ranges: [ClosedRange<UInt32>]) -> Bool { text.string.unicodeScalars.contains { u in ranges.contains { $0.contains(u.value) } } }
    let unspaced = has([0x3040...0x30FF, 0x4E00...0x9FFF, 0x0E00...0x0E7F])  // Japanese, Chinese, Thai
    let breakAfter = CharacterSet.whitespacesAndNewlines.subtracting(CharacterSet(charactersIn: "\u{00A0}")).union(CharacterSet(charactersIn: "-–—/"))
    for (i, line) in lines.enumerated() where i < lines.count - 1 {
        let r = CTLineGetStringRange(line)
        let end = r.location + r.length
        guard end > 0, end < s.length else { continue }
        let before = s.character(at: end - 1), after = s.character(at: end)
        if before == wj || after == wj { return false }
        if !unspaced, let u = Unicode.Scalar(before), !breakAfter.contains(u),
           let v = Unicode.Scalar(after), !CharacterSet.whitespaces.contains(v) { return false }
    }
    guard lines.count > 1, let last = lines.last else { return true }
    // Balance: no line under 30% of the widest one (a lone "잠금" on top, or "記録。" hanging below).
    let widths = lines.map { CGFloat(CTLineGetTypographicBounds($0, nil, nil, nil) - CTLineGetTrailingWhitespaceWidth($0)) }
    if let widest = widths.max(), widths.contains(where: { $0 < widest * 0.3 }) { return false }
    let r = CTLineGetStringRange(last)
    let tail = s.substring(with: NSRange(location: r.location, length: r.length))
        .replacingOccurrences(of: "\u{2060}", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
    let letters = tail.unicodeScalars.filter { CharacterSet.letters.contains($0) || CharacterSet.decimalDigits.contains($0) }
    // Korean words are long units, so treat Hangul like CJK here: only a single character is a widow.
    let noSpaceWidow = unspaced || has([0xAC00...0xD7AF])
    // A long last word ("otključavanja.", "Zdravlje.") reads fine; a short one ("tap.") is a widow.
    return noSpaceWidow ? letters.count > 1 : (tail.split(whereSeparator: \.isWhitespace).count > 1 || tail.count >= 8)
}

/// Largest size (≤ 124) at which the headline fits `box` in at most 3 lines with good breaks. At each size it first
/// tries narrower (centred) widths, so a widow rebalances ("Log a hot flash / in one tap.") instead of shrinking the
/// font. Failing everything, the largest size that simply fits. Returns the width to draw in.
func fitted(_ text: String, box: CGSize, rtl: Bool) -> (CTFramesetter, CGSize, CGFloat) {
    var size: CGFloat = 124
    var fallback: (CTFramesetter, CGSize, CGFloat)?
    while size > 60 {
        let attributed = headline(text, size: size, rtl: rtl)
        let fs = CTFramesetterCreateWithAttributedString(attributed)
        for factor: CGFloat in [1.0, 0.9, 0.8, 0.7, 0.6] {
            let width = box.width * factor
            let path = CGPath(rect: CGRect(origin: .zero, size: CGSize(width: width, height: 10_000)), transform: nil)
            let lines = (CTFrameGetLines(CTFramesetterCreateFrame(fs, CFRange(), path, nil)) as? [CTLine]) ?? []
            let need = CTFramesetterSuggestFrameSizeWithConstraints(fs, CFRange(), nil, CGSize(width: width, height: .greatestFiniteMagnitude), nil)
            guard lines.count <= 3, need.height <= box.height else { continue }
            if goodBreaks(lines, in: attributed) { return (fs, need, width) }
            if fallback == nil, factor == 1.0 { fallback = (fs, need, width) }
        }
        size -= 4
    }
    if let fallback { return fallback }
    let fs = CTFramesetterCreateWithAttributedString(headline(text, size: 60, rtl: rtl))
    return (fs, CTFramesetterSuggestFrameSizeWithConstraints(fs, CFRange(), nil, CGSize(width: box.width, height: .greatestFiniteMagnitude), nil), box.width)
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
        let kept = text.replacingOccurrences(of: "Apple Watch", with: "Apple\u{00A0}Watch").replacingOccurrences(of: "Apple Health", with: "Apple\u{00A0}Health")
        let (fs, need, textWidth) = fitted(phraseGlued(kept, lang: lang), box: box, rtl: frame.rtl ?? false)
        let top: CGFloat = 170
        let rect = CGRect(x: (CGFloat(W) - textWidth) / 2, y: CGFloat(H) - top - need.height, width: textWidth, height: need.height + 4)
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
