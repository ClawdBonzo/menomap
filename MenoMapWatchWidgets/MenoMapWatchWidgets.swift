import SwiftUI
import WidgetKit
import MenoCore

@main
struct MenoMapWatchWidgets: WidgetBundle {
    var body: some Widget { SurgeComplication() }
}

struct WatchEntry: TimelineEntry {
    let date: Date
    let todayCount: Int
}

struct WatchProvider: TimelineProvider {
    private func count() -> Int {
        guard let data = UserDefaults(suiteName: MenoShared.appGroupID)?.data(forKey: MenoShared.snapshotKey),
              let s = try? JSONDecoder().decode(MenoSnapshot.self, from: data) else { return 0 }
        // A snapshot from an earlier day doesn't count toward today.
        return Calendar.current.isDateInToday(s.updatedAt) ? s.todayCount : 0
    }

    func placeholder(in context: Context) -> WatchEntry { WatchEntry(date: .now, todayCount: 2) }
    func getSnapshot(in context: Context, completion: @escaping (WatchEntry) -> Void) {
        completion(WatchEntry(date: .now, todayCount: context.isPreview ? 2 : count()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchEntry>) -> Void) {
        let midnight = Calendar.current.startOfDay(for: .now.addingTimeInterval(86400))
        completion(Timeline(entries: [WatchEntry(date: .now, todayCount: count())], policy: .after(midnight)))
    }
}

/// Tap → opens the Watch app on the Surge button. Shows today's count.
struct SurgeComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "app.gwlabs.menomap.watch.surge", provider: WatchProvider()) { entry in
            SurgeComplicationView(entry: entry)
                .containerBackground(.clear, for: .widget)
                .widgetURL(URL(string: "menomap://surge"))
        }
        .configurationDisplayName("Surge")
        .description("One tap to start timing a surge.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryRectangular, .accessoryInline])
    }
}

struct SurgeComplicationView: View {
    let entry: WatchEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCorner:
            Image(systemName: "flame.fill").font(.title2)
                .widgetLabel { Text("Surge · \(entry.todayCount)") }
        case .accessoryRectangular:
            VStack(alignment: .leading) {
                Label("Surge", systemImage: "flame.fill").font(.headline).widgetAccentable()
                Text("Today: \(entry.todayCount)").font(.caption)
            }
        case .accessoryInline:
            Label("Surges today: \(entry.todayCount)", systemImage: "flame")
        default:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Image(systemName: "flame.fill").font(.title3).widgetAccentable()
                    Text("\(entry.todayCount)").font(.caption2.monospacedDigit())
                }
            }
        }
    }
}
