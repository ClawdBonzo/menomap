import SwiftUI
import MenoCore

/// Seven-day heat strip: one ember cell per day, count printed in the cell, weekday + sleep under it.
struct HeatStrip: View {
    let days: [DayHeat]
    var showSleep = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(days.enumerated()), id: \.element.day) { idx, d in
                VStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(MenoTheme.heat(appeared ? d.level : 0))
                        .overlay {
                            if d.level == 0 {
                                RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(MenoTheme.hairline)
                            }
                        }
                        .overlay {
                            Text("\(d.count)")
                                .font(.system(.body, design: .serif).weight(.semibold).monospacedDigit())
                                .foregroundStyle(d.count == 0 ? MenoTheme.inkSecondary : MenoTheme.onHeat(d.level))
                        }
                        .frame(height: 52)
                        .animation(reduceMotion ? nil : .easeOut(duration: 0.4).delay(Double(idx) * 0.05), value: appeared)
                    Text(Copy.shortWeekday(d.day))
                        .font(.caption.weight(d.day == .today() ? .bold : .regular))
                        .foregroundStyle(d.day == .today() ? MenoTheme.ink : MenoTheme.inkSecondary)
                    if showSleep {
                        Text(d.sleepScore.map { "\($0)" } ?? "·")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(MenoTheme.teal)
                    }
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(accessibility(for: d)))
            }
        }
        .onAppear { appeared = true }
    }

    private func accessibility(for d: DayHeat) -> String {
        let date = d.day.startDate().formatted(.dateTime.weekday(.wide).day().month())
        var s = String(localized: "\(date): \(d.count) surges")
        if let sleep = d.sleepScore { s += ", " + String(localized: "sleep \(sleep) of 10") }
        return s
    }
}

/// Month-style heat calendar for 30/90/365-day views: rows are weeks, cells are days.
struct HeatCalendar: View {
    let days: [DayHeat]
    var cell: CGFloat = 0

    private var weeks: [[DayHeat?]] {
        guard let first = days.first else { return [] }
        // Pad the first week so columns line up with the locale's first weekday.
        let firstWeekday = Calendar.current.firstWeekday
        let lead = (first.day.weekday() - firstWeekday + 7) % 7
        var cells: [DayHeat?] = Array(repeating: nil, count: lead) + days.map { Optional($0) }
        while cells.count % 7 != 0 { cells.append(nil) }
        return stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0..<$0 + 7]) }
    }

    var body: some View {
        let showNumbers = days.count <= 35
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                ForEach(0..<7, id: \.self) { i in
                    let wd = (Calendar.current.firstWeekday - 1 + i) % 7
                    Text(Calendar.current.veryShortWeekdaySymbols[wd])
                        .font(.caption2).foregroundStyle(MenoTheme.inkSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .accessibilityHidden(true)
            ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                HStack(spacing: 4) {
                    ForEach(0..<7, id: \.self) { i in
                        if let d = week[i] {
                            RoundedRectangle(cornerRadius: showNumbers ? 6 : 3, style: .continuous)
                                .fill(MenoTheme.heat(d.level))
                                .aspectRatio(1, contentMode: .fit)
                                .overlay {
                                    if showNumbers && d.count > 0 {
                                        Text("\(d.count)").font(.caption2.weight(.semibold).monospacedDigit())
                                            .foregroundStyle(MenoTheme.onHeat(d.level))
                                    }
                                }
                                .overlay {
                                    if d.day == .today() {
                                        RoundedRectangle(cornerRadius: showNumbers ? 6 : 3).strokeBorder(MenoTheme.teal, lineWidth: 1.5)
                                    }
                                }
                                .accessibilityElement()
                                .accessibilityLabel(Text("\(d.day.startDate().formatted(date: .abbreviated, time: .omitted)): \(d.count) surges"))
                        } else {
                            Color.clear.aspectRatio(1, contentMode: .fit)
                        }
                    }
                }
            }
        }
    }
}

struct HeatLegend: View {
    var body: some View {
        HStack(spacing: 6) {
            Text("Calm").font(.caption2).foregroundStyle(MenoTheme.inkSecondary).fixedSize()
            ForEach(0...5, id: \.self) { l in
                RoundedRectangle(cornerRadius: 3).fill(MenoTheme.heat(l)).frame(width: 14, height: 14)
            }
            Text("Hot").font(.caption2).foregroundStyle(MenoTheme.inkSecondary).fixedSize()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Heat scale from calm to hot. Each cell also shows its number of surges."))
    }
}
