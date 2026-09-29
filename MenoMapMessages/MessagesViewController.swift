import Messages
import SwiftUI
import UIKit

/// iMessage app: MenoMap stickers and branded heads-up cards. Every one sent links back to MenoMap.
/// Nothing from the user's health log is used or sent.
final class MessagesViewController: MSMessagesAppViewController {
    private var host: UIHostingController<MessagesRootView>?

    override func viewDidLoad() {
        super.viewDidLoad()
        let root = MessagesRootView(send: { [weak self] text in self?.sendCard(text) },
                                    expand: { [weak self] in self?.requestPresentationStyle(.expanded) })
        let h = UIHostingController(rootView: root)
        addChild(h)
        h.view.translatesAutoresizingMaskIntoConstraints = false
        h.view.backgroundColor = .clear
        view.addSubview(h.view)
        NSLayoutConstraint.activate([
            h.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            h.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            h.view.topAnchor.constraint(equalTo: view.topAnchor),
            h.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        h.didMove(toParent: self)
        host = h
    }

    /// Heads-up card: a branded bubble with the text; tapping it opens gwlabs.app/menomap.
    private func sendCard(_ text: String) {
        guard let conversation = activeConversation else { return }
        let layout = MSMessageTemplateLayout()
        layout.image = StickerFactory.cardImage(text)
        layout.caption = text
        layout.subcaption = "MenoMap"
        let message = MSMessage(session: MSSession())
        message.layout = layout
        message.url = URL(string: "https://gwlabs.app/menomap")
        message.summaryText = text
        conversation.insert(message) { _ in }
        requestPresentationStyle(.compact)
    }
}

struct MessagesRootView: View {
    let send: (String) -> Void
    let expand: () -> Void
    @State private var tab = 0

    var body: some View {
        VStack(spacing: 8) {
            Picker("", selection: $tab) {
                Text("Stickers").tag(0)
                Text("Heads-up").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            .padding(.top, 8)
            if tab == 0 {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 10)], spacing: 10) {
                        ForEach(Array(HeadsUpTexts.stickers.enumerated()), id: \.offset) { i, text in
                            StickerCell(index: i, text: text).frame(height: 100)
                        }
                    }
                    .padding(12)
                }
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(HeadsUpTexts.headsUps, id: \.self) { t in
                            Button { send(t) } label: {
                                HStack {
                                    Text(t).font(.body).foregroundStyle(Color(hex: 0x1E2524)).multilineTextAlignment(.leading)
                                    Spacer()
                                    Image(systemName: "paperplane.fill").foregroundStyle(Color(hex: 0x0D6B66))
                                }
                                .padding(14)
                                .background(Color(hex: 0xFBF8F4), in: RoundedRectangle(cornerRadius: 14))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(12)
                }
                .onAppear(perform: expand)
            }
        }
        .background(Color(hex: 0xF3EEE7))
    }
}

/// Wraps MSStickerView so stickers can be tapped to send or peeled onto a bubble.
struct StickerCell: UIViewRepresentable {
    let index: Int
    let text: String

    func makeUIView(context: Context) -> MSStickerView {
        let v = MSStickerView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        v.sticker = StickerFactory.sticker(index: index, text: text)
        return v
    }

    func updateUIView(_ uiView: MSStickerView, context: Context) {}
}

@MainActor
enum StickerFactory {
    /// Renders (once, cached per language) a 618×618 PNG sticker.
    static func sticker(index: Int, text: String) -> MSSticker? {
        let lang = Locale.current.language.languageCode?.identifier ?? "en"
        let dir = FileManager.default.temporaryDirectory.appending(path: "stickers-\(lang)-v1", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appending(path: "s\(index).png")
        if !FileManager.default.fileExists(atPath: url.path) {
            let r = ImageRenderer(content: StickerArt(text: text, style: index % 3).frame(width: 206, height: 206))
            r.scale = 3
            r.isOpaque = false
            guard let data = r.uiImage?.pngData() else { return nil }
            try? data.write(to: url)
        }
        return try? MSSticker(contentsOfFileURL: url, localizedDescription: text)
    }

    static func cardImage(_ text: String) -> UIImage? {
        let r = ImageRenderer(content: HeadsUpArt(text: text).frame(width: 300, height: 200))
        r.scale = 3
        return r.uiImage
    }
}

/// Sticker look: an ember contour badge (or stone / teal variants) with a serif line.
struct StickerArt: View {
    let text: String
    let style: Int

    /// Shrinks so the longest word always fits on one line (no mid-word breaks in any language).
    private var fontSize: CGFloat {
        let longest = text.split(whereSeparator: { $0.isWhitespace }).map(\.count).max() ?? 8
        return min(26, 140 / (CGFloat(longest) * 0.6))
    }

    var body: some View {
        let (fill, ink): (Color, Color) = switch style {
        case 0: (Color(hex: 0xD4552A), .white)
        case 1: (Color(hex: 0xF3EEE7), Color(hex: 0xD4552A))
        default: (Color(hex: 0x0D6B66), .white)
        }
        ZStack {
            Blob(seed: style + text.count).fill(fill)
            Blob(seed: style + text.count).stroke(.white, lineWidth: 6)
            Blob(seed: style + text.count + 2).stroke(ink.opacity(0.25), lineWidth: 2).scaleEffect(0.86)
            Text(text)
                .font(.system(size: fontSize, weight: .bold, design: .serif))
                .multilineTextAlignment(.center)
                .foregroundStyle(ink)
                .minimumScaleFactor(0.5)
                .padding(26)
        }
        .padding(6)
    }
}

struct HeadsUpArt: View {
    let text: String

    var body: some View {
        ZStack {
            Color(hex: 0xF3EEE7)
            ForEach(0..<5, id: \.self) { i in
                Blob(seed: i).stroke(Color(hex: 0xD4552A).opacity(0.12 + Double(i) * 0.08), lineWidth: 2)
                    .scaleEffect(1.3 - CGFloat(i) * 0.18)
                    .offset(x: 110, y: -40)
            }
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: "moon.haze.fill").font(.title).foregroundStyle(Color(hex: 0xD4552A))
                Text(text).font(.system(size: 22, weight: .semibold, design: .serif)).foregroundStyle(Color(hex: 0x1E2524))
                    .minimumScaleFactor(0.6)
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
    }
}

struct Blob: Shape {
    var seed: Int

    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        var p = Path()
        for k in 0...120 {
            let a = Double(k) / 120 * 2 * .pi
            let w = 0.93 + 0.05 * sin(3 * a + Double(seed)) + 0.03 * sin(5 * a - Double(seed) * 0.6)
            let pt = CGPoint(x: c.x + CGFloat(cos(a) * w) * r, y: c.y + CGFloat(sin(a) * w) * r)
            if k == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}
