import Foundation

/// One heat-map cell. `level` 0…5 drives the ember opacity; `count` is always printed too
/// (color is never the only signal).
public struct DayHeat: Codable, Hashable, Sendable {
    public var day: DayKey
    public var count: Int
    public var level: Int
    public var avgIntensity: Double?
    public var sleepScore: Int?

    public init(day: DayKey, count: Int, level: Int, avgIntensity: Double?, sleepScore: Int?) {
        self.day = day
        self.count = count
        self.level = level
        self.avgIntensity = avgIntensity
        self.sleepScore = sleepScore
    }
}

public enum HeatScale {
    /// Unrated surges count as a 3 when computing a day's heat load.
    public static let unratedWeight = 3

    /// Heat load = sum of intensities that day. 0 → 0, 1–3 → 1, 4–6 → 2, 7–10 → 3, 11–15 → 4, 16+ → 5.
    public static func level(forLoad load: Int) -> Int {
        switch load {
        case ..<1: 0
        case 1...3: 1
        case 4...6: 2
        case 7...10: 3
        case 11...15: 4
        default: 5
        }
    }

    public static func load(of surges: [SurgeRecord]) -> Int {
        surges.reduce(0) { $0 + ($1.intensity ?? unratedWeight) }
    }
}

public struct ClockTime: Codable, Hashable, Sendable {
    public var hour: Int
    public var minute: Int
    public init(hour: Int, minute: Int) { self.hour = hour; self.minute = minute }
}

/// Everything the Stats screen, Heat Report, share cards and PDF need for one window.
public struct SurgeStats: Hashable, Sendable {
    public var window: DayWindow
    public var total: Int
    public var hotFlashes: Int
    public var nightSweats: Int
    /// Surges started 21:00–06:59, whatever kind was chosen.
    public var nightSurges: Int
    public var rated: Int
    public var avgIntensity: Double?
    /// Average of known durations (after-the-fact buckets count at their midpoint; unknown is skipped).
    public var avgDurationSec: Int?
    public var longestSec: Int?
    public var shortestSec: Int?
    /// 24 buckets, local hour of day.
    public var hourHistogram: [Int]
    /// Peak hour and its median minute, when there are at least 5 surges.
    public var peakTime: ClockTime?
    public var tagCounts: [SurgeTag: Int]
    public var days: [DayHeat]
    /// The logged day with the lowest heat load (ties → most recent). Nil with fewer than 3 logged days.
    public var calmestDay: DayKey?
    /// Longest run of consecutive days with zero surges inside the window, counted only after the first logged day.
    public var longestCalmStretch: Int
    public var loggedDays: Int

    public var perDayAverage: Double {
        loggedDays == 0 ? 0 : Double(total) / Double(loggedDays)
    }
}

public enum StatsCalculator {
    public static func compute(window: DayWindow, surges allSurges: [SurgeRecord], checkIns: [CheckInRecord],
                               calendar: Calendar = .menoGregorian) -> SurgeStats {
        let surges = allSurges.filter { window.contains(DayKey($0.startedAt, calendar: calendar)) }
        let byDay = Dictionary(grouping: surges) { DayKey($0.startedAt, calendar: calendar) }
        let checkInByDay = Dictionary(checkIns.map { ($0.day, $0) }, uniquingKeysWith: { a, _ in a })

        var days: [DayHeat] = []
        for d in window.days(calendar: calendar) {
            let list = byDay[d] ?? []
            let ratings = list.compactMap(\.intensity)
            days.append(DayHeat(
                day: d,
                count: list.count,
                level: HeatScale.level(forLoad: HeatScale.load(of: list)),
                avgIntensity: ratings.isEmpty ? nil : Double(ratings.reduce(0, +)) / Double(ratings.count),
                sleepScore: checkInByDay[d]?.scores[.sleep]
            ))
        }

        let ratings = surges.compactMap(\.intensity)
        let durations = surges.map(\.durationSec).filter { $0 > 0 }
        var hist = Array(repeating: 0, count: 24)
        var minutesByHour: [Int: [Int]] = [:]
        for s in surges {
            let h = calendar.component(.hour, from: s.startedAt)
            let m = calendar.component(.minute, from: s.startedAt)
            hist[h] += 1
            minutesByHour[h, default: []].append(m)
        }
        var peak: ClockTime?
        if surges.count >= 5, let maxCount = hist.max(), maxCount > 0,
           let hour = hist.indices.last(where: { hist[$0] == maxCount }) {
            let mins = (minutesByHour[hour] ?? [0]).sorted()
            peak = ClockTime(hour: hour, minute: mins[mins.count / 2])
        }

        var tags: [SurgeTag: Int] = [:]
        for s in surges { for t in s.tags { tags[t, default: 0] += 1 } }

        let loggedSet = Set(byDay.keys).union(checkIns.map(\.day).filter { window.contains($0) })
        var calmest: DayKey?
        if loggedSet.count >= 3 {
            let logged = days.filter { loggedSet.contains($0.day) }
            let loadOf: (DayHeat) -> Int = { HeatScale.load(of: byDay[$0.day] ?? []) }
            calmest = logged.min { a, b in
                let la = loadOf(a), lb = loadOf(b)
                return la != lb ? la < lb : a.day > b.day
            }?.day
        }

        var longest = 0, run = 0, started = false
        for d in days {
            if loggedSet.contains(d.day) { started = true }
            guard started else { continue }
            if d.count == 0 { run += 1; longest = max(longest, run) } else { run = 0 }
        }

        return SurgeStats(
            window: window,
            total: surges.count,
            hotFlashes: surges.filter { $0.kind == .hotFlash }.count,
            nightSweats: surges.filter { $0.kind == .nightSweat }.count,
            nightSurges: surges.filter { $0.isNight(calendar: calendar) }.count,
            rated: ratings.count,
            avgIntensity: ratings.isEmpty ? nil : Double(ratings.reduce(0, +)) / Double(ratings.count),
            avgDurationSec: durations.isEmpty ? nil : durations.reduce(0, +) / durations.count,
            longestSec: durations.max(),
            shortestSec: durations.min(),
            hourHistogram: hist,
            peakTime: peak,
            tagCounts: tags,
            days: days,
            calmestDay: calmest,
            longestCalmStretch: longest,
            loggedDays: loggedSet.count
        )
    }

    /// Averages for each metric over the window, only across days that have a score.
    public static func checkInAverages(window: DayWindow, checkIns: [CheckInRecord]) -> [TrackedMetric: (avg: Double, n: Int)] {
        var sums: [TrackedMetric: (Int, Int)] = [:]
        for c in checkIns where window.contains(c.day) {
            for (m, v) in c.scores {
                let cur = sums[m] ?? (0, 0)
                sums[m] = (cur.0 + v, cur.1 + 1)
            }
        }
        return sums.mapValues { (avg: Double($0.0) / Double($0.1), n: $0.1) }
    }
}

/// How ready the user's notes are for an upcoming appointment (0…1), with what's missing.
public struct VisitReadiness: Hashable, Sendable {
    public enum Gap: String, Hashable, Sendable, CaseIterable {
        case moreLoggedDays, logSurges, checkIns, medications, questions
    }

    public var score: Double
    public var gaps: [Gap]

    /// Weights: logged days (target 14 in the last 30) 40%, surges (5) 15%, check-ins (7) 20%,
    /// medications entered or confirmed none 10%, at least one question picked 15%.
    public static func compute(loggedDaysLast30: Int, surgesLast30: Int, checkInsLast30: Int,
                               medicationsDone: Bool, questionsPicked: Int) -> VisitReadiness {
        func part(_ v: Int, _ target: Int) -> Double { min(Double(v) / Double(target), 1) }
        let score = 0.40 * part(loggedDaysLast30, 14)
            + 0.15 * part(surgesLast30, 5)
            + 0.20 * part(checkInsLast30, 7)
            + 0.10 * (medicationsDone ? 1 : 0)
            + 0.15 * (questionsPicked > 0 ? 1 : 0)
        var gaps: [Gap] = []
        if loggedDaysLast30 < 14 { gaps.append(.moreLoggedDays) }
        if surgesLast30 < 5 { gaps.append(.logSurges) }
        if checkInsLast30 < 7 { gaps.append(.checkIns) }
        if !medicationsDone { gaps.append(.medications) }
        if questionsPicked == 0 { gaps.append(.questions) }
        return VisitReadiness(score: (score * 100).rounded() / 100, gaps: gaps)
    }
}
