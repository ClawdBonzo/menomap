#if DEBUG
import SwiftUI
import MenoCore

/// Screenshot-only renderings of surfaces the simulator can't capture per language (Lock Screen Live Activity,
/// Apple Watch). They reuse the exact strings of the widget and Watch targets, so every language is covered.
/// Launch with `-MMShowcase nightwatch|watch`.
enum Showcase {
    static var kind: String? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-MMShowcase"), i + 1 < args.count else { return nil }
        return args[i + 1]
    }
}

struct ShowcaseView: View {
    let kind: String

    var body: some View {
        switch kind {
        case "watch": WatchShowcase()
        case "patterns": PatternsShowcase()
        case "pdf": PDFShowcase()
        case "experiment": ExperimentShowcase()
        case "privacy": NavigationStack { PrivacyView() }
        default: NightWatchShowcase()
        }
    }
}

private let nightInk = Color(hex: 0xC9503A)

struct PatternsShowcase: View {
    @Environment(MenoStore.self) private var store

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    PatternsSection(insights: InsightEngine().compute(store.insightInput(), today: .today())
                        .filter { $0.ruleID != InsightRuleID.experimentResult })
                }
                .padding(16)
            }
            .menoScreen()
            .navigationTitle("Your weather")
        }
    }
}

struct PDFShowcase: View {
    @Environment(MenoStore.self) private var store

    var body: some View {
        let input = VisitPDFInput.build(store: store, appointment: store.nextAppointment(), windowDays: 30,
                                        languageCode: Bundle.main.preferredLocalizations.first ?? "en",
                                        paper: RegionInfo.paperSize(regionCode: Locale.current.region?.identifier), preview: false)
        let data = VisitPDFRenderer().makePDF(input)
        NavigationStack {
            PDFKitView(data: data)
                .navigationTitle("Your notes")
                .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            // `-MMExportSamplePDF`: also save the PDF to Documents (the website's demo-data sample for clinicians).
            guard ProcessInfo.processInfo.arguments.contains("-MMExportSamplePDF"),
                  let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
            try? data.write(to: docs.appendingPathComponent("sample-notes.pdf"))
        }
    }
}

struct ExperimentShowcase: View {
    @Environment(MenoStore.self) private var store

    var body: some View {
        let result = InsightEngine().experimentResults(store.insightInput(), today: .today()).first
        ZStack {
            MenoTheme.ground.ignoresSafeArea()
            if let result {
                ShareCard(kind: .experiment(result), format: .story, voice: store.profile().voice, showQR: false, watermark: false)
                    .frame(width: 360, height: 640)
                    .shadow(color: .black.opacity(0.15), radius: 24, y: 12)
            }
        }
    }
}

struct NightWatchShowcase: View {
    private var night: Date {
        Calendar.current.date(bySettingHour: 2, minute: 47, second: 0, of: .now) ?? .now
    }

    private var wake: Date {
        Calendar.current.date(bySettingHour: 6, minute: 30, second: 0, of: .now) ?? .now
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x10141F), Color(hex: 0x1B1320), Color(hex: 0x2A1712)], startPoint: .top, endPoint: .bottom)
                .overlay {
                    ContourShape(seed: 5).stroke(Color(hex: 0xC9503A, opacity: 0.14), lineWidth: 1.5)
                        .frame(width: 700, height: 700).offset(x: 160, y: -260)
                }
                .clipped()
                .ignoresSafeArea()
            VStack(spacing: 0) {
                Text(night.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(.system(size: 20, weight: .semibold)).foregroundStyle(.white.opacity(0.85))
                    .padding(.top, 70)
                Text(verbatim: Locale.current.hourCycle == .oneToTwelve || Locale.current.hourCycle == .zeroToEleven ? "2:47" : "02:47")
                    .font(.system(size: 104, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.9))
                Spacer()
                VStack(spacing: 12) {
                    card(active: false)
                    card(active: true)
                }
                .padding(.horizontal, 14)
                HStack {
                    circle("flashlight.off.fill")
                    Spacer()
                    circle("camera.fill")
                }
                .padding(.horizontal, 46)
                .padding(.top, 36)
                .padding(.bottom, 24)
            }
        }
        .environment(\.colorScheme, .dark)
        .statusBarHidden()
    }

    private func circle(_ symbol: String) -> some View {
        Image(systemName: symbol).font(.title3).foregroundStyle(.white)
            .frame(width: 50, height: 50).background(.white.opacity(0.15), in: Circle())
    }

    /// Mirrors NightWatchLiveActivity (widget target) with the same strings.
    @ViewBuilder private func card(active: Bool) -> some View {
        HStack(spacing: 14) {
            if active {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Night sweat").font(.headline).foregroundStyle(nightInk)
                    Text("1:24").font(.system(.title, design: .serif).monospacedDigit()).foregroundStyle(nightInk)
                    Text("In 4 · hold 4 · out 4").font(.caption).foregroundStyle(nightInk.opacity(0.7))
                }
                Spacer()
                Text("End").font(.title3.weight(.semibold)).foregroundStyle(nightInk)
                    .frame(minWidth: 90, minHeight: 50).background(nightInk.opacity(0.22), in: Capsule())
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    Label("Night Watch", systemImage: "moon.stars.fill").font(.subheadline.weight(.semibold)).foregroundStyle(nightInk)
                    Text("\(2) tonight").font(.caption).foregroundStyle(nightInk.opacity(0.7))
                    Text("Until \(wake, style: .time)").font(.caption2).foregroundStyle(nightInk.opacity(0.6))
                }
                Spacer()
                Label("Night sweat", systemImage: "drop.fill").font(.title3.weight(.semibold)).foregroundStyle(nightInk)
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .frame(minWidth: 150, minHeight: 56).background(nightInk.opacity(0.22), in: Capsule())
            }
        }
        .padding()
        .background(Color.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
}

struct WatchShowcase: View {
    private let teal = Color(red: 0.32, green: 0.72, blue: 0.68)
    private let ember = Color(red: 0.94, green: 0.48, blue: 0.30)

    var body: some View {
        ZStack {
            MenoTheme.ground
                .overlay {
                    ContourShape(seed: 3).stroke(MenoTheme.ember.opacity(0.18), lineWidth: 1.5).frame(width: 720, height: 720).offset(x: 140, y: -120)
                }
                .clipped()
                .ignoresSafeArea()
            VStack(spacing: 26) {
                watch {
                    VStack(spacing: 10) {
                        VStack(spacing: 6) {
                            Image(systemName: "moon.haze.fill").font(.system(size: 34))
                            Text("Night sweat").font(.system(size: 22, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 130)
                        .background(nightInk, in: RoundedRectangle(cornerRadius: 34, style: .continuous))
                        Text("Hot flash").font(.system(size: 17)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 50).background(Color.white.opacity(0.15), in: Capsule())
                        Text("Today: \(2)").font(.system(size: 15)).foregroundStyle(.white.opacity(0.6))
                    }
                }
                watch {
                    VStack(spacing: 8) {
                        Text("How strong?").font(.system(size: 20, weight: .semibold)).foregroundStyle(.white)
                        Text("Turn the Crown").font(.system(size: 13)).foregroundStyle(.white.opacity(0.6))
                        Text("3").font(.system(size: 64, weight: .semibold, design: .serif)).foregroundStyle(ember)
                        Text("Strong").font(.system(size: 14)).foregroundStyle(.white.opacity(0.6))
                        Text("Save").font(.system(size: 18, weight: .semibold)).foregroundStyle(teal)
                            .frame(maxWidth: .infinity, minHeight: 50).background(teal.opacity(0.22), in: Capsule())
                    }
                }
            }
        }
        .statusBarHidden()
    }

    private func watch<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(22)
            .frame(width: 290, height: 330)
            .background(Color.black, in: RoundedRectangle(cornerRadius: 70, style: .continuous))
            .padding(14)
            .background(LinearGradient(colors: [Color(hex: 0x3A3A3C), Color(hex: 0x1C1C1E)], startPoint: .top, endPoint: .bottom),
                        in: RoundedRectangle(cornerRadius: 84, style: .continuous))
            .overlay(alignment: .trailing) {
                RoundedRectangle(cornerRadius: 6).fill(Color(hex: 0x3A3A3C)).frame(width: 14, height: 70).offset(x: 12, y: -60)
            }
            .shadow(color: .black.opacity(0.25), radius: 24, y: 12)
    }
}
#endif
