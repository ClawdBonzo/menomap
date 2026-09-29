import SwiftUI
import Charts
import MenoCore

enum StatsRange: Int, CaseIterable, Identifiable {
    case week = 7, month = 30, quarter = 90, year = 365
    var id: Int { rawValue }

    var label: LocalizedStringKey {
        switch self {
        case .week: "7 days"
        case .month: "30 days"
        case .quarter: "90 days"
        case .year: "Year"
        }
    }

    var isPro: Bool { self != .week }
}

struct WeekView: View {
    @Environment(MenoStore.self) private var store
    @Environment(SubscriptionManager.self) private var subscription
    @Environment(AppRouter.self) private var router
    @State private var range: StatsRange = .week
    @State private var showShare = false

    var body: some View {
        let _ = store.revision
        let today = DayKey.today()
        let window = DayWindow(lastDays: range.rawValue, endingOn: today)
        let checkIns = store.checkInRecords(in: window)
        let stats = StatsCalculator.compute(window: window, surges: store.surgeRecords(in: window), checkIns: checkIns)
        let prev = StatsCalculator.compute(window: window.previous(), surges: store.surgeRecords(in: window.previous()), checkIns: [])
        let locked = range.isPro && !subscription.isPro
        let voice = store.profile().voice
        let insights = InsightEngine().compute(store.insightInput(), today: today)

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Picker("Range", selection: $range) {
                        ForEach(StatsRange.allCases) { r in Text(r.label).tag(r) }
                    }
                    .pickerStyle(.segmented)

                    Group {
                        ThermostatCard(stats: stats, previous: prev, range: range, voice: voice)
                        MenoCard {
                            SectionHeader(title: "Heat map")
                            if range == .week { HeatStrip(days: stats.days) } else { HeatCalendar(days: stats.days) }
                            HeatLegend()
                        }
                        SurgeClockCard(stats: stats, voice: voice)
                        TriggerPodiumCard(stats: stats)
                        RecordsCard(stats: stats, voice: voice)
                        CheckInTrendCard(window: window, checkIns: checkIns, metrics: store.profile().trackedMetrics)
                    }
                    .blur(radius: locked ? 8 : 0)
                    .overlay {
                        if locked {
                            LockedOverlay(title: "See the month, not just the day",
                                          message: "30, 90 and 365-day views are part of MenoMap Pro.") {
                                router.present(.paywall(.stats))
                            }
                        }
                    }
                    .allowsHitTesting(!locked)
                    .overlay { if locked { Color.clear.contentShape(Rectangle()).onTapGesture { router.present(.paywall(.stats)) } } }

                    PatternsSection(insights: insights)
                    ExperimentsSection()
                    HeatReportEntry()
                    RecentEntriesSection()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .menoScreen()
            .navigationTitle("Your weather")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showShare = true } label: { Label("Share", systemImage: "square.and.arrow.up") }
                }
            }
            .sheet(isPresented: $showShare) {
                ShareCardSheet(kind: .week(stats: StatsCalculator.compute(window: DayWindow(lastDays: 7, endingOn: today),
                                                                          surges: store.surgeRecords(in: DayWindow(lastDays: 7, endingOn: today)),
                                                                          checkIns: [])))
            }
        }
    }
}

struct LockedOverlay: View {
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.fill").font(.title2).foregroundStyle(MenoTheme.teal)
            Text(title).font(MenoTheme.headline(.title3)).foregroundStyle(MenoTheme.ink).multilineTextAlignment(.center)
            Text(message).font(.subheadline).foregroundStyle(MenoTheme.inkSecondary).multilineTextAlignment(.center)
            Button("Unlock with Pro", action: action).buttonStyle(.menoPrimary).frame(maxWidth: 260)
        }
        .padding(24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.horizontal, 24)
        .padding(.top, 40)
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

// MARK: - Thermostat

struct ThermostatCard: View {
    let stats: SurgeStats
    let previous: SurgeStats
    let range: StatsRange
    let voice: VoiceStyle

    var body: some View {
        let change: Double? = previous.total > 0 ? Double(stats.total - previous.total) / Double(previous.total) : nil
        MenoCard {
            HStack(alignment: .center, spacing: 18) {
                ThermostatGauge(value: min(stats.perDayAverage / 6, 1), label: stats.perDayAverage.formatted(.number.precision(.fractionLength(1))))
                    .frame(width: 120, height: 120)
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(stats.total)")
                        .font(MenoTheme.number(.largeTitle)).foregroundStyle(MenoTheme.ink)
                    Text(range == .week ? Copy.weekHeadline(count: stats.total, voice: voice) : String(localized: "surges in \(range.rawValue) days"))
                        .font(.subheadline.weight(.semibold)).foregroundStyle(MenoTheme.ink)
                    if let change {
                        let down = change < 0
                        Label("\(Int(abs(change) * 100))% \(down ? String(localized: "fewer") : String(localized: "more")) than the \(range.rawValue) days before",
                              systemImage: down ? "arrow.down.right" : "arrow.up.right")
                            .font(.caption).foregroundStyle(down ? MenoTheme.teal : MenoTheme.ember)
                    }
                    Text("\(stats.hotFlashes) hot flashes · \(stats.nightSweats) night sweats")
                        .font(.caption).foregroundStyle(MenoTheme.inkSecondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Half-dial from calm (teal) to hot (ember); needle = surges per logged day (0…6+).
struct ThermostatGauge: View {
    let value: Double
    let label: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = 0.0

    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0.125, to: 0.875)
                .stroke(AngularGradient(colors: [MenoTheme.teal, MenoTheme.ember.opacity(0.5), MenoTheme.ember],
                                        center: .center, startAngle: .degrees(135), endAngle: .degrees(405)),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(90))
            Capsule()
                .fill(MenoTheme.ink)
                .frame(width: 4, height: 44)
                .offset(y: -22)
                .rotationEffect(.degrees(-135 + 270 * shown))
            Circle().fill(MenoTheme.ink).frame(width: 12, height: 12)
            VStack(spacing: 0) {
                Spacer()
                Text(label).font(.system(.headline, design: .serif).monospacedDigit()).foregroundStyle(MenoTheme.ink)
                Text("a day").font(.caption2).foregroundStyle(MenoTheme.inkSecondary)
            }
            .padding(.bottom, 4)
        }
        .onAppear {
            if reduceMotion { shown = value } else { withAnimation(.spring(duration: 0.9)) { shown = value } }
        }
        .onChange(of: value) { _, v in withAnimation(reduceMotion ? nil : .spring(duration: 0.6)) { shown = v } }
        .accessibilityLabel(Text("\(label) surges a day"))
    }
}

// MARK: - Surge clock

struct SurgeClockCard: View {
    let stats: SurgeStats
    let voice: VoiceStyle

    var body: some View {
        MenoCard {
            SectionHeader(title: "Surge clock")
            if stats.total == 0 {
                Text("Your surges will appear around the clock here.").font(.subheadline).foregroundStyle(MenoTheme.inkSecondary)
            } else {
                HStack(spacing: 16) {
                    SurgeClock(histogram: stats.hourHistogram).frame(width: 150, height: 150)
                    VStack(alignment: .leading, spacing: 8) {
                        if let peak = stats.peakTime {
                            Text(Copy.peakLine(peak, voice: voice)).font(MenoTheme.headline(.headline)).foregroundStyle(MenoTheme.ink)
                        }
                        let night = stats.total == 0 ? 0 : Int((Double(stats.nightSurges) / Double(stats.total) * 100).rounded())
                        Text("\(night)% at night (9pm–7am)").font(.subheadline).foregroundStyle(MenoTheme.inkSecondary)
                    }
                }
            }
        }
    }
}

/// 24-hour radial histogram; midnight at the top.
struct SurgeClock: View {
    let histogram: [Int]

    var body: some View {
        let maxV = max(histogram.max() ?? 1, 1)
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let inner = size * 0.2
            let outer = size * 0.5
            ZStack {
                Circle().stroke(MenoTheme.hairline, lineWidth: 1).frame(width: inner * 2, height: inner * 2)
                ForEach(0..<24, id: \.self) { h in
                    let v = Double(histogram[h]) / Double(maxV)
                    let len = (outer - inner) * max(v, 0.04)
                    Capsule()
                        .fill(v == 0 ? MenoTheme.hairline : MenoTheme.ember.opacity(0.3 + 0.7 * v))
                        .frame(width: max(size * 0.035, 4), height: len)
                        .offset(y: -(inner + len / 2))
                        .rotationEffect(.degrees(Double(h) / 24 * 360))
                }
                ForEach([0, 6, 12, 18], id: \.self) { h in
                    Text(h == 0 ? "12a" : h == 12 ? "12p" : h == 6 ? "6a" : "6p")
                        .font(.system(size: 9, weight: .semibold)).foregroundStyle(MenoTheme.inkSecondary)
                        .offset(y: -(inner - 10))
                        .rotationEffect(.degrees(Double(h) / 24 * 360))
                }
            }
            .frame(width: size, height: size)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .accessibilityElement()
        .accessibilityLabel(Text("Surges by hour of day"))
    }
}

// MARK: - Trigger podium

struct TriggerPodiumCard: View {
    let stats: SurgeStats

    var body: some View {
        let top = stats.tagCounts.filter { $0.key != .unknown }.sorted { $0.value > $1.value }.prefix(3)
        MenoCard {
            SectionHeader(title: "Most-tagged")
            if top.isEmpty {
                Text("Tag a few surges (alcohol, heat, stress…) and your top three land here.")
                    .font(.subheadline).foregroundStyle(MenoTheme.inkSecondary)
            } else {
                let order = podiumOrder(Array(top))
                let maxV = Double(top.first?.value ?? 1)
                HStack(alignment: .bottom, spacing: 12) {
                    ForEach(order, id: \.key) { item in
                        let place = (top.firstIndex { $0.key == item.key } ?? 0) + 1
                        VStack(spacing: 6) {
                            Image(systemName: Copy.tagSymbol(item.key)).font(.title3).foregroundStyle(MenoTheme.ember)
                            Text(Copy.tag(item.key)).font(.caption.weight(.semibold)).foregroundStyle(MenoTheme.ink).lineLimit(1)
                                .minimumScaleFactor(0.8)
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(MenoTheme.ember.opacity(place == 1 ? 0.9 : place == 2 ? 0.6 : 0.35))
                                .frame(height: 30 + 70 * Double(item.value) / maxV)
                                .overlay(alignment: .top) {
                                    Text("\(item.value)").font(.system(.headline, design: .serif).monospacedDigit())
                                        .foregroundStyle(place == 1 ? .white : MenoTheme.ink).padding(.top, 6)
                                }
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityElement(children: .combine)
                    }
                }
                Text("Tags you chose. Counting them together doesn't show a cause.")
                    .font(.caption).foregroundStyle(MenoTheme.inkSecondary)
            }
        }
    }

    private func podiumOrder(_ items: [(key: SurgeTag, value: Int)]) -> [(key: SurgeTag, value: Int)] {
        switch items.count {
        case 3: [items[1], items[0], items[2]]
        default: items
        }
    }
}

// MARK: - Records

struct RecordsCard: View {
    let stats: SurgeStats
    let voice: VoiceStyle

    var body: some View {
        MenoCard {
            SectionHeader(title: "Records")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 14) {
                record("Longest", stats.longestSec.map(Copy.duration) ?? "–")
                record("Shortest", stats.shortestSec.map(Copy.duration) ?? "–")
                record("Typical length", stats.avgDurationSec.map(Copy.duration) ?? "–")
                record("Average strength", stats.avgIntensity.map { "\($0.formatted(.number.precision(.fractionLength(1)))) / 5" } ?? "–")
                record("Calmest day", stats.calmestDay.map(Copy.date) ?? "–")
                record("Calm stretch", String(localized: "\(stats.longestCalmStretch) days"))
            }
            if stats.longestCalmStretch > 0 {
                Text(Copy.calmStretchLine(stats.longestCalmStretch, voice: voice))
                    .font(MenoTheme.headline(.subheadline)).foregroundStyle(MenoTheme.teal)
            }
        }
    }

    private func record(_ title: LocalizedStringKey, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(MenoTheme.inkSecondary)
            Text(value).font(.system(.title3, design: .serif).weight(.semibold).monospacedDigit()).foregroundStyle(MenoTheme.ink)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Check-in trend

struct CheckInTrendCard: View {
    let window: DayWindow
    let checkIns: [CheckInRecord]
    let metrics: [TrackedMetric]

    var body: some View {
        let shown = metrics.filter { [.sleep, .mood, .energy, .brainFog, .stress].contains($0) }.prefix(3)
        let points: [(DayKey, TrackedMetric, Int)] = checkIns.flatMap { c in shown.compactMap { m in c.scores[m].map { (c.day, m, $0) } } }
        MenoCard {
            SectionHeader(title: "Check-ins")
            if points.count < 3 {
                Text("A few evening check-ins and your sleep, mood and energy lines appear here.")
                    .font(.subheadline).foregroundStyle(MenoTheme.inkSecondary)
            } else {
                Chart {
                    ForEach(Array(points.enumerated()), id: \.offset) { _, p in
                        LineMark(x: .value("Day", p.0.startDate(), unit: .day), y: .value("Score", p.2))
                            .foregroundStyle(by: .value("Metric", Copy.metricShort(p.1)))
                            .interpolationMethod(.monotone)
                        PointMark(x: .value("Day", p.0.startDate(), unit: .day), y: .value("Score", p.2))
                            .foregroundStyle(by: .value("Metric", Copy.metricShort(p.1)))
                            .symbolSize(window.count <= 7 ? 30 : 8)
                    }
                }
                .chartYScale(domain: 0...10)
                .chartForegroundStyleScale(range: [MenoTheme.teal, MenoTheme.ink.opacity(0.6), MenoTheme.ember.opacity(0.7)])
                .frame(height: 170)
                let avg = StatsCalculator.checkInAverages(window: window, checkIns: checkIns)
                HStack(spacing: 16) {
                    ForEach(Array(shown), id: \.self) { m in
                        if let a = avg[m] {
                            VStack(alignment: .leading, spacing: 0) {
                                Text(Copy.metricShort(m)).font(.caption).foregroundStyle(MenoTheme.inkSecondary)
                                Text(a.avg.formatted(.number.precision(.fractionLength(1)))).font(.system(.headline, design: .serif).monospacedDigit())
                            }
                        }
                    }
                }
            }
        }
    }
}
