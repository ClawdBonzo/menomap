import AppIntents
import ActivityKit
import SwiftUI
import WidgetKit
import MenoCore

@main
struct MenoMapWidgetsBundle: WidgetBundle {
    var body: some Widget {
        SurgeButtonWidget()
        HeatWeekWidget()
        CountdownWidget()
        SurgeControl()
        NightWatchControl()
        SurgeLiveActivity()
        NightWatchLiveActivity()
    }
}

// MARK: - Palette (mirrors MenoTheme; widgets can't see the app target)

enum W {
    static func dyn(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) })
    }
    static let ground = dyn(0xF3EEE7, 0x151311)
    static let ink = dyn(0x1E2524, 0xF2ECE4)
    static let ink2 = dyn(0x5E6663, 0xB5ADA3)
    static let teal = dyn(0x0D6B66, 0x52B8AE)
    static let onTeal = dyn(0xFFFFFF, 0x0B1F1D)
    static let ember = dyn(0xD4552A, 0xF07A4C)
    static let hair = dyn(0xE3DDD5, 0x2E2A26)
    static let heatOpacity: [Double] = [0, 0.14, 0.30, 0.48, 0.70, 0.94]
    static func heat(_ l: Int) -> Color { l <= 0 ? hair : ember.opacity(heatOpacity[min(l, 5)]) }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

// MARK: - Timeline

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: MenoSnapshot
}

struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry { SnapshotEntry(date: .now, snapshot: .preview) }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        completion(SnapshotEntry(date: .now, snapshot: context.isPreview ? .preview : SnapshotStore.read()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let entry = SnapshotEntry(date: .now, snapshot: SnapshotStore.read())
        // Refresh after midnight so "today" rolls over even if the app isn't opened.
        let tomorrow = Calendar.current.startOfDay(for: .now.addingTimeInterval(86400)).addingTimeInterval(60)
        completion(Timeline(entries: [entry], policy: .after(tomorrow)))
    }
}

extension MenoSnapshot {
    static var preview: MenoSnapshot {
        let today = DayKey.today()
        let counts = [3, 5, 2, 4, 1, 2, 2]
        return MenoSnapshot(todayCount: 2,
                            last7: (0..<7).map { i in .init(day: today.adding(days: i - 6), count: counts[i], level: min(5, counts[i])) },
                            appointment: .init(date: .now.addingTimeInterval(9 * 86400), readiness: 0.7),
                            activeSurge: nil, isPro: true, updatedAt: .now)
    }
}

// MARK: - Surge button (small, interactive; also Lock Screen circular)

struct SurgeButtonWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "app.gwlabs.menomap.surge", provider: SnapshotProvider()) { entry in
            SurgeButtonView(entry: entry)
        }
        .configurationDisplayName("Surge button")
        .description("Start timing a hot flash in one tap.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}

struct SurgeButtonView: View {
    let entry: SnapshotEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            Button(intent: StartSurgeIntent(kind: .hotFlash)) {
                ZStack {
                    AccessoryWidgetBackground()
                    Image(systemName: entry.snapshot.activeSurge == nil ? "flame.fill" : "timer")
                        .font(.title2.weight(.semibold))
                }
            }
            .buttonStyle(.plain)
            .containerBackground(.clear, for: .widget)
            .widgetAccentable()
            .accessibilityLabel(Text("Start a surge"))
        case .accessoryRectangular:
            Button(intent: StartSurgeIntent(kind: .hotFlash)) {
                VStack(alignment: .leading, spacing: 2) {
                    Label("Surge", systemImage: "flame.fill").font(.headline)
                    Text("Today: \(entry.snapshot.todayCount)").font(.caption)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .containerBackground(.clear, for: .widget)
        default:
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Today").font(.caption.weight(.semibold)).foregroundStyle(W.ink2)
                    Spacer()
                    Text("\(entry.snapshot.todayCount)").font(.system(.title3, design: .serif).weight(.semibold)).foregroundStyle(W.ink)
                }
                Spacer(minLength: 0)
                if let active = entry.snapshot.activeSurge {
                    Button(intent: EndSurgeIntent()) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(active.startedAt, style: .timer).font(.system(.title2, design: .serif).monospacedDigit())
                            Text("Tap to end").font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(W.onTeal)
                        .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
                        .padding(.horizontal, 12)
                        .background(W.ember, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(intent: StartSurgeIntent(kind: .hotFlash)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Image(systemName: "flame.fill").font(.title2)
                            Text("I'm having a surge").font(.system(.subheadline, design: .serif).weight(.semibold))
                                .multilineTextAlignment(.leading)
                        }
                        .foregroundStyle(W.onTeal)
                        .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
                        .padding(.horizontal, 12)
                        .background(W.teal, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .containerBackground(W.ground, for: .widget)
        }
    }
}

// MARK: - 7-day heat (medium)

struct HeatWeekWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "app.gwlabs.menomap.heat", provider: SnapshotProvider()) { entry in
            HeatWeekView(entry: entry)
        }
        .configurationDisplayName("Last 7 days")
        .description("Your heat map, with a surge button.")
        .supportedFamilies([.systemMedium])
    }
}

struct HeatWeekView: View {
    let entry: SnapshotEntry

    var body: some View {
        let total = entry.snapshot.last7.reduce(0) { $0 + $1.count }
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Last 7 days").font(.system(.headline, design: .serif)).foregroundStyle(W.ink)
                Spacer()
                Text("\(total) surges").font(.caption.weight(.semibold)).foregroundStyle(W.ink2)
            }
            HStack(spacing: 5) {
                ForEach(entry.snapshot.last7, id: \.day) { c in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(W.heat(c.level))
                            .overlay { Text("\(c.count)").font(.system(.subheadline, design: .serif).weight(.semibold)).foregroundStyle(c.level >= 4 ? .white : W.ink) }
                        Text(c.day.startDate().formatted(.dateTime.weekday(.narrow))).font(.caption2).foregroundStyle(W.ink2)
                    }
                }
            }
            Button(intent: StartSurgeIntent(kind: .hotFlash)) {
                Label("I'm having a surge", systemImage: "flame.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(W.onTeal)
                    .frame(maxWidth: .infinity, minHeight: 34)
                    .background(W.teal, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .containerBackground(W.ground, for: .widget)
        .widgetURL(URL(string: "menomap://week"))
    }
}

// MARK: - Appointment countdown

struct CountdownWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "app.gwlabs.menomap.countdown", provider: SnapshotProvider()) { entry in
            CountdownView(entry: entry)
        }
        .configurationDisplayName("Appointment countdown")
        .description("Days to your next appointment and how ready your notes are.")
        .supportedFamilies([.systemSmall, .accessoryInline])
    }
}

struct CountdownView: View {
    let entry: SnapshotEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if let appt = entry.snapshot.appointment {
            let days = max(DayKey.today().days(to: DayKey(appt.date)), 0)
            if family == .accessoryInline {
                Text("Appointment in \(days)d · notes \(Int(appt.readiness * 100))%")
                    .containerBackground(.clear, for: .widget)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Appointment").font(.caption.weight(.semibold)).foregroundStyle(W.ink2)
                    Text(days == 0 ? String(localized: "Today") : String(localized: "\(days) days"))
                        .font(.system(.title, design: .serif).weight(.semibold)).foregroundStyle(W.ink)
                    Spacer(minLength: 0)
                    Gauge(value: appt.readiness) { EmptyView() }
                        .gaugeStyle(.accessoryLinearCapacity)
                        .tint(W.teal)
                    Text("Notes \(Int(appt.readiness * 100))% ready").font(.caption).foregroundStyle(W.ink2)
                }
                .containerBackground(W.ground, for: .widget)
                .widgetURL(URL(string: "menomap://visit"))
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: "calendar.badge.plus").font(.title2).foregroundStyle(W.teal)
                Text("Add your next appointment").font(.system(.subheadline, design: .serif).weight(.semibold)).foregroundStyle(W.ink)
            }
            .containerBackground(W.ground, for: .widget)
            .widgetURL(URL(string: "menomap://visit"))
        }
    }
}

// MARK: - Control Center / Lock Screen / Action Button control

struct SurgeControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "app.gwlabs.menomap.control.surge") {
            ControlWidgetButton(action: StartSurgeIntent(kind: .hotFlash)) {
                Label("Start a surge", systemImage: "flame.fill")
            }
        }
        .displayName("Start a surge")
        .description("Starts timing a hot flash in MenoMap.")
    }
}

struct NightWatchControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "app.gwlabs.menomap.control.nightwatch") {
            ControlWidgetButton(action: ArmNightWatchIntent()) {
                Label("Night Watch", systemImage: "moon.stars.fill")
            }
        }
        .displayName("Night Watch")
        .description("Puts a one-tap night sweat button on your Lock Screen until morning.")
    }
}

// MARK: - Night Watch Live Activity

/// Deliberately dark and dim: it sits on the Lock Screen all night.
struct NightWatchLiveActivity: Widget {
    private let ink = Color(hex: 0xC9503A)

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: NightWatchAttributes.self) { context in
            HStack(spacing: 14) {
                if let start = context.state.activeSurgeStart {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Night sweat").font(.headline).foregroundStyle(ink)
                        Text(timerInterval: start...Date.distantFuture, countsDown: false)
                            .font(.system(.title, design: .serif).monospacedDigit()).foregroundStyle(ink)
                        Text("In 4 · hold 4 · out 4").font(.caption).foregroundStyle(ink.opacity(0.7))
                    }
                    Spacer()
                    Button(intent: EndSurgeIntent()) {
                        Text("End").font(.title3.weight(.semibold)).frame(minWidth: 90, minHeight: 50)
                    }
                    .tint(ink)
                } else {
                    VStack(alignment: .leading, spacing: 3) {
                        Label("Night Watch", systemImage: "moon.stars.fill").font(.subheadline.weight(.semibold)).foregroundStyle(ink)
                        Text(context.state.tonightCount == 0 ? String(localized: "Quiet so far.")
                             : String(localized: "\(context.state.tonightCount) tonight"))
                            .font(.caption).foregroundStyle(ink.opacity(0.7))
                        Text("Until \(context.attributes.wakeAt, style: .time)").font(.caption2).foregroundStyle(ink.opacity(0.6))
                    }
                    Spacer()
                    Button(intent: StartSurgeIntent(kind: .nightSweat)) {
                        Label("Night sweat", systemImage: "drop.fill")
                            .font(.title3.weight(.semibold))
                            .frame(minWidth: 150, minHeight: 56)
                    }
                    .tint(ink)
                }
            }
            .padding()
            .activityBackgroundTint(Color.black)
            .activitySystemActionForegroundColor(ink)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { Image(systemName: "moon.stars.fill").foregroundStyle(ink) }
                DynamicIslandExpandedRegion(.center) { Text("Night Watch").font(.headline) }
                DynamicIslandExpandedRegion(.bottom) {
                    if context.state.activeSurgeStart != nil {
                        Button(intent: EndSurgeIntent()) { Text("End").frame(maxWidth: .infinity) }.tint(ink)
                    } else {
                        Button(intent: StartSurgeIntent(kind: .nightSweat)) { Text("Night sweat").frame(maxWidth: .infinity) }.tint(ink)
                    }
                }
            } compactLeading: {
                Image(systemName: "moon.stars.fill").foregroundStyle(ink)
            } compactTrailing: {
                if let start = context.state.activeSurgeStart {
                    Text(timerInterval: start...Date.distantFuture, countsDown: false).monospacedDigit().frame(width: 44)
                } else {
                    Text("\(context.state.tonightCount)").monospacedDigit()
                }
            } minimal: {
                Image(systemName: "moon.stars.fill").foregroundStyle(ink)
            }
        }
    }
}

// MARK: - Live Activity

struct SurgeLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SurgeActivityAttributes.self) { context in
            let night = context.state.isNight
            let accent = night ? Color(hex: 0xC9503A) : W.teal
            HStack(spacing: 14) {
                Image(systemName: context.state.kind == .nightSweat ? "moon.haze.fill" : "flame.fill")
                    .font(.title2).foregroundStyle(accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.state.kind == .nightSweat ? "Night sweat" : "Hot flash")
                        .font(.headline).foregroundStyle(night ? Color(hex: 0xC9503A) : .primary)
                    Text(timerInterval: context.attributes.startedAt...Date.distantFuture, countsDown: false)
                        .font(.system(.title2, design: .serif).monospacedDigit())
                        .foregroundStyle(night ? Color(hex: 0xC9503A) : .primary)
                    Text("In 4 · hold 4 · out 4").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(spacing: 8) {
                    Button(intent: EndSurgeIntent()) {
                        Text("End").font(.headline).frame(minWidth: 64, minHeight: 36)
                    }
                    .tint(accent)
                    Button(intent: ToggleSurgeKindIntent()) {
                        Text(context.state.kind == .nightSweat ? "Hot flash" : "Night sweat").font(.caption)
                    }
                    .tint(.secondary)
                }
            }
            .padding()
            .activityBackgroundTint(night ? Color.black : nil)
            .activitySystemActionForegroundColor(accent)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.state.kind == .nightSweat ? "moon.haze.fill" : "flame.fill").foregroundStyle(W.ember)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: context.attributes.startedAt...Date.distantFuture, countsDown: false)
                        .font(.system(.title3, design: .serif).monospacedDigit()).frame(width: 70)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.kind == .nightSweat ? "Night sweat" : "Hot flash").font(.headline)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text("In 4 · hold 4 · out 4").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button(intent: EndSurgeIntent()) { Text("End").font(.headline) }.tint(W.teal)
                    }
                }
            } compactLeading: {
                Image(systemName: "flame.fill").foregroundStyle(W.ember)
            } compactTrailing: {
                Text(timerInterval: context.attributes.startedAt...Date.distantFuture, countsDown: false)
                    .monospacedDigit().frame(width: 44)
            } minimal: {
                Image(systemName: "flame.fill").foregroundStyle(W.ember)
            }
            .widgetURL(URL(string: "menomap://surge"))
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}
