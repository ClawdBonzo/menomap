import SwiftUI
import CoreImage.CIFilterBuiltins
import MenoCore

/// Opt-in share cards. Numbers only; rendered on device; medication names off by default.
enum ShareCardKind: Identifiable {
    case week(stats: SurgeStats)
    case month(stats: SurgeStats, previousTotal: Int, title: String)
    case experiment(Insight)
    case calmStretch(days: Int)

    var id: String {
        switch self {
        case .week: "week"
        case .month: "month"
        case .experiment(let i): i.id
        case .calmStretch: "calm"
        }
    }
}

enum CardFormat: String, CaseIterable, Identifiable {
    case story, square
    var id: String { rawValue }
    var size: CGSize { self == .story ? CGSize(width: 360, height: 640) : CGSize(width: 360, height: 360) }
}

/// Fixed palette so cards look the same in light and dark mode.
enum CardPalette {
    static let ground = Color(hex: 0xF3EEE7)
    static let ink = Color(hex: 0x1E2524)
    static let ink2 = Color(hex: 0x5E6663)
    static let ember = Color(hex: 0xD4552A)
    static let teal = Color(hex: 0x0D6B66)
    static let hair = Color(hex: 0x1E2524, opacity: 0.1)
    static func heat(_ l: Int) -> Color { l == 0 ? hair : ember.opacity(MenoTheme.heatOpacity[min(max(l, 0), 5)]) }
}

struct ShareCardSheet: View {
    let kind: ShareCardKind
    @Environment(MenoStore.self) private var store
    @Environment(SubscriptionManager.self) private var subscription
    @Environment(\.dismiss) private var dismiss
    @State private var format: CardFormat = .story
    @State private var rendered: UIImage?

    var body: some View {
        let profile = store.profile()
        NavigationStack {
            VStack(spacing: 16) {
                Picker("Format", selection: $format) {
                    Text("Story").tag(CardFormat.story)
                    Text("Square").tag(CardFormat.square)
                }
                .pickerStyle(.segmented)

                ShareCard(kind: kind, format: format, voice: profile.voice, showQR: profile.showQROnShare,
                          watermark: !subscription.isPro)
                    .frame(width: format.size.width, height: format.size.height)
                    .scaleEffect(format == .story ? 0.78 : 0.95)
                    .frame(height: format == .story ? 500 : 345)
                    .shadow(color: .black.opacity(0.12), radius: 20, y: 10)
                    .accessibilityElement(children: .combine)

                Toggle("Show App Store QR code", isOn: Binding(get: { profile.showQROnShare }, set: { profile.showQROnShare = $0; store.save() }))
                    .font(.subheadline)

                if let rendered {
                    ShareLink(item: Image(uiImage: rendered), preview: SharePreview("MenoMap", image: Image(uiImage: rendered))) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.menoPrimary)
                }
                if case .week(let stats) = kind {
                    StoryVideoButton(stats: stats, title: String(localized: "This week"), headline: Copy.weekHeadline(count: stats.total, voice: profile.voice))
                }
                Text("Only numbers. No notes, medication names or health details leave your phone unless you send them.")
                    .font(.caption).foregroundStyle(MenoTheme.inkSecondary).multilineTextAlignment(.center)
            }
            .padding(20)
            .menoScreen()
            .navigationTitle("Share card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .task(id: "\(format.rawValue)-\(profile.showQROnShare)") { render(profile) }
        }
    }

    @MainActor private func render(_ profile: UserProfile) {
        let card = ShareCard(kind: kind, format: format, voice: profile.voice, showQR: profile.showQROnShare, watermark: !subscription.isPro)
            .frame(width: format.size.width, height: format.size.height)
            .environment(\.colorScheme, .light)
        let r = ImageRenderer(content: card)
        r.scale = 3
        rendered = r.uiImage
    }
}

struct ShareCard: View {
    let kind: ShareCardKind
    let format: CardFormat
    let voice: VoiceStyle
    let showQR: Bool
    let watermark: Bool

    var body: some View {
        ZStack {
            CardPalette.ground
            ContourBackdrop().opacity(0.5)
            VStack(alignment: .leading, spacing: format == .story ? 22 : 12) {
                HStack {
                    Text("MenoMap").font(.system(size: 15, weight: .semibold, design: .serif)).foregroundStyle(CardPalette.ink)
                    Spacer()
                    Text(subtitle).font(.system(size: 11, weight: .semibold)).tracking(1).foregroundStyle(CardPalette.ink2)
                }
                if format == .story { Spacer(minLength: 0) }
                content
                if format == .story { Spacer(minLength: 0) }
                footer
            }
            .padding(format == .story ? 28 : 22)
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var subtitle: String {
        switch kind {
        case .week(let s): Copy.caps("\(Copy.date(s.window.start)) – \(Copy.date(s.window.end))")
        case .month(_, _, let title): Copy.caps(title)
        case .experiment: String(localized: "EXPERIMENT")
        case .calmStretch: String(localized: "RECORD")
        }
    }

    @ViewBuilder private var content: some View {
        switch kind {
        case .week(let s):
            Text(Copy.weekHeadline(count: s.total, voice: voice))
                .font(.system(size: format == .story ? 38 : 26, weight: .semibold, design: .serif))
                .foregroundStyle(CardPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 6) {
                ForEach(s.days, id: \.day) { d in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 8).fill(CardPalette.heat(d.level))
                            .frame(height: format == .story ? 64 : 40)
                            .overlay { Text("\(d.count)").font(.system(size: 15, weight: .semibold, design: .serif)).foregroundStyle(d.level >= 4 ? .white : CardPalette.ink) }
                        Text(Copy.shortWeekday(d.day)).font(.system(size: 11)).foregroundStyle(CardPalette.ink2)
                    }
                }
            }
            statRow([
                (String(localized: "Typical"), s.avgDurationSec.map(Copy.duration) ?? "–"),
                (String(localized: "Peak"), s.peakTime.map(Copy.clock) ?? "–"),
                (String(localized: "Calm stretch"), String(localized: "\(s.longestCalmStretch)d")),
            ])
            if format == .story, let peak = s.peakTime {
                Text(Copy.peakLine(peak, voice: voice)).font(.system(size: 17, weight: .medium, design: .serif)).foregroundStyle(CardPalette.teal)
            }

        case .month(let s, let prev, _):
            Text("\(s.total)").font(.system(size: format == .story ? 96 : 56, weight: .semibold, design: .serif)).foregroundStyle(CardPalette.ink)
            Text(voice == .wry ? String(localized: "personal summers last month") : String(localized: "surges last month"))
                .font(.system(size: 18, weight: .medium, design: .serif)).foregroundStyle(CardPalette.ink)
            if prev > 0 {
                let diff = s.total - prev
                Text(diff <= 0 ? String(localized: "\(abs(diff)) fewer than the month before") : String(localized: "\(diff) more than the month before"))
                    .font(.system(size: 14, weight: .semibold)).foregroundStyle(diff <= 0 ? CardPalette.teal : CardPalette.ember)
            }
            if format == .story {
                MiniCalendar(days: s.days)
            }
            statRow([
                (String(localized: "Peak"), s.peakTime.map(Copy.clock) ?? "–"),
                (String(localized: "Calmest"), s.calmestDay.map(Copy.date) ?? "–"),
                (String(localized: "Calm stretch"), String(localized: "\(s.longestCalmStretch)d")),
            ])

        case .experiment(let i):
            if case let .experimentResult(_, k, measure, b, bDays, d, dDays) = i.kind {
                Text(Copy.experiment(k)).font(.system(size: format == .story ? 32 : 24, weight: .semibold, design: .serif)).foregroundStyle(CardPalette.ink)
                HStack(alignment: .bottom, spacing: 24) {
                    bigNumber("\(b)", String(localized: "\(bDays) days before"), CardPalette.ember)
                    Image(systemName: "arrow.forward").font(.title2).foregroundStyle(CardPalette.ink2)
                    bigNumber("\(d)", String(localized: "\(dDays) days during"), CardPalette.teal)
                }
                Text(measure == .nightSurges ? String(localized: "night surges logged") : String(localized: "surges logged"))
                    .font(.system(size: 15, weight: .medium)).foregroundStyle(CardPalette.ink2)
                Text("My own entries. Not proof of cause.").font(.system(size: 12)).foregroundStyle(CardPalette.ink2)
            }

        case .calmStretch(let days):
            Text("\(days)").font(.system(size: 110, weight: .semibold, design: .serif)).foregroundStyle(CardPalette.teal)
            Text(Copy.calmStretchLine(days, voice: voice)).font(.system(size: 22, weight: .semibold, design: .serif)).foregroundStyle(CardPalette.ink)
        }
    }

    private func bigNumber(_ n: String, _ label: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(n).font(.system(size: format == .story ? 72 : 48, weight: .semibold, design: .serif)).foregroundStyle(color)
            Text(label).font(.system(size: 12, weight: .semibold)).foregroundStyle(CardPalette.ink2)
        }
    }

    private func statRow(_ items: [(String, String)]) -> some View {
        HStack(alignment: .top) {
            ForEach(items, id: \.0) { title, value in
                VStack(alignment: .leading, spacing: 2) {
                    Text(Copy.caps(title)).font(.system(size: 10, weight: .semibold)).tracking(0.8).foregroundStyle(CardPalette.ink2)
                    Text(value).font(.system(size: 18, weight: .semibold, design: .serif)).foregroundStyle(CardPalette.ink)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var footer: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Logged with MenoMap").font(.system(size: 12, weight: .semibold)).foregroundStyle(CardPalette.ink)
                Text("gwlabs.app/menomap").font(.system(size: 11)).foregroundStyle(CardPalette.ink2)
                if watermark {
                    Text("Free version").font(.system(size: 10)).foregroundStyle(CardPalette.ink2.opacity(0.7))
                }
            }
            Spacer()
            if showQR, let qr = QRCode.image(for: LegalLinks.appStore.absoluteString) {
                Image(uiImage: qr).interpolation(.none).resizable().frame(width: 54, height: 54)
                    .accessibilityLabel(Text("QR code for MenoMap"))
            }
        }
    }
}

struct MiniCalendar: View {
    let days: [DayHeat]
    var body: some View {
        let cols = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
        LazyVGrid(columns: cols, spacing: 4) {
            ForEach(days, id: \.day) { d in
                RoundedRectangle(cornerRadius: 4).fill(CardPalette.heat(d.level)).aspectRatio(1, contentMode: .fit)
            }
        }
    }
}

struct ContourBackdrop: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<7, id: \.self) { i in
                    ContourShape(seed: i + 3)
                        .stroke(CardPalette.ember.opacity(0.07 + Double(i) * 0.015), lineWidth: 1.2)
                        .frame(width: geo.size.width * (1.6 - CGFloat(i) * 0.18), height: geo.size.width * (1.6 - CGFloat(i) * 0.18))
                        .position(x: geo.size.width * 0.9, y: geo.size.height * 0.1)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

enum QRCode {
    static func image(for string: String) -> UIImage? {
        let f = CIFilter.qrCodeGenerator()
        f.message = Data(string.utf8)
        f.correctionLevel = "M"
        guard let out = f.outputImage?.transformed(by: CGAffineTransform(scaleX: 8, y: 8)),
              let cg = CIContext().createCGImage(out, from: out.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}

// MARK: - Heat Report

struct HeatReportView: View {
    @Environment(MenoStore.self) private var store
    @Environment(SubscriptionManager.self) private var subscription
    @Environment(AppRouter.self) private var router
    @State private var sharing: ShareCardKind?

    /// The last complete calendar month.
    private var month: (DayWindow, String) {
        let cal = Calendar.menoGregorian
        let startThis = cal.date(from: cal.dateComponents([.year, .month], from: .now)) ?? .now
        let startPrev = cal.date(byAdding: .month, value: -1, to: startThis) ?? .now
        let end = DayKey(startThis).adding(days: -1)
        let title = startPrev.formatted(.dateTime.month(.wide).year())
        return (DayWindow(start: DayKey(startPrev), end: end), title)
    }

    var body: some View {
        let (window, title) = month
        let stats = StatsCalculator.compute(window: window, surges: store.surgeRecords(in: window), checkIns: store.checkInRecords(in: window))
        let prev = StatsCalculator.compute(window: window.previous(), surges: store.surgeRecords(in: window.previous()), checkIns: [])
        let voice = store.profile().voice
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(title).font(MenoTheme.headline(.largeTitle))
                ShareCard(kind: .month(stats: stats, previousTotal: prev.total, title: title), format: .story, voice: voice,
                          showQR: false, watermark: false)
                    .frame(width: 360, height: 640)
                    .scaleEffect(0.9)
                    .frame(maxWidth: .infinity)
                    .frame(height: 580)
                Button { sharing = .month(stats: stats, previousTotal: prev.total, title: title) } label: {
                    Label("Share the cover", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.menoSecondary)
                StoryVideoButton(stats: stats, title: title,
                                 headline: voice == .wry ? String(localized: "personal summers last month") : String(localized: "surges last month"))
                Group {
                    SurgeClockCard(stats: stats, voice: voice)
                    TriggerPodiumCard(stats: stats)
                    RecordsCard(stats: stats, voice: voice)
                    if stats.longestCalmStretch >= 3 {
                        Button { sharing = .calmStretch(days: stats.longestCalmStretch) } label: {
                            Label("Share your calm stretch", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.menoQuiet)
                    }
                }
                .blur(radius: subscription.isPro ? 0 : 8)
                .overlay {
                    if !subscription.isPro {
                        LockedOverlay(title: "The full Heat Report", message: "The cover is free. The rest of the month is Pro.") {
                            router.present(.paywall(.stats))
                        }
                    }
                }
            }
            .padding(16)
        }
        .menoScreen()
        .navigationTitle("Heat Report")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $sharing) { ShareCardSheet(kind: $0) }
    }
}
