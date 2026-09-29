import Foundation

/// A calendar day, always in the Gregorian calendar and the user's current time zone.
///
/// Every window (7/30/90 days), heat-map cell and pairing rule works in whole calendar days, never
/// rolling 24-hour spans, so a DST change never drops or duplicates a day. Buddhist, Japanese or
/// Islamic device calendars do not change day keys (a WishLock lesson).
public struct DayKey: Hashable, Codable, Comparable, Sendable, CustomStringConvertible {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    public init(_ date: Date, calendar: Calendar = .menoGregorian) {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: c.year ?? 1970, month: c.month ?? 1, day: c.day ?? 1)
    }

    public static func today(now: Date = .now, calendar: Calendar = .menoGregorian) -> DayKey {
        DayKey(now, calendar: calendar)
    }

    /// Local midnight at the start of this day.
    public func startDate(calendar: Calendar = .menoGregorian) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .distantPast
    }

    /// Local midnight at the start of the next day (exclusive end of this day).
    public func endDate(calendar: Calendar = .menoGregorian) -> Date {
        adding(days: 1, calendar: calendar).startDate(calendar: calendar)
    }

    public func adding(days: Int, calendar: Calendar = .menoGregorian) -> DayKey {
        // Anchor at noon so DST transitions (which happen at night) never shift the day.
        let noon = calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)) ?? .distantPast
        let moved = calendar.date(byAdding: .day, value: days, to: noon) ?? noon
        return DayKey(moved, calendar: calendar)
    }

    /// Whole calendar days from `self` to `other` (positive when `other` is later).
    public func days(to other: DayKey, calendar: Calendar = .menoGregorian) -> Int {
        let a = calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)) ?? .distantPast
        let b = calendar.date(from: DateComponents(year: other.year, month: other.month, day: other.day, hour: 12)) ?? .distantPast
        return calendar.dateComponents([.day], from: a, to: b).day ?? 0
    }

    /// 1 = Sunday … 7 = Saturday (Gregorian weekday numbering).
    public func weekday(calendar: Calendar = .menoGregorian) -> Int {
        calendar.component(.weekday, from: startDate(calendar: calendar).addingTimeInterval(12 * 3600))
    }

    public static func < (lhs: DayKey, rhs: DayKey) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    public var description: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    /// Parses "YYYY-MM-DD".
    public init?(string: String) {
        let parts = string.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        self.init(year: parts[0], month: parts[1], day: parts[2])
    }
}

public extension Calendar {
    /// Gregorian calendar in the current time zone. Used for every day key.
    static var menoGregorian: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        cal.locale = Locale(identifier: "en_US_POSIX")
        return cal
    }
}

/// An inclusive run of calendar days ending on `end`.
public struct DayWindow: Hashable, Sendable {
    public let start: DayKey
    public let end: DayKey

    public init(start: DayKey, end: DayKey) {
        self.start = start
        self.end = end
    }

    /// The `days` calendar days ending on (and including) `end`.
    public init(lastDays days: Int, endingOn end: DayKey, calendar: Calendar = .menoGregorian) {
        self.end = end
        self.start = end.adding(days: -(max(days, 1) - 1), calendar: calendar)
    }

    public func contains(_ day: DayKey) -> Bool { day >= start && day <= end }

    public func days(calendar: Calendar = .menoGregorian) -> [DayKey] {
        var out: [DayKey] = []
        var d = start
        while d <= end {
            out.append(d)
            d = d.adding(days: 1, calendar: calendar)
        }
        return out
    }

    public var count: Int { start.days(to: end) + 1 }

    /// The window of the same length immediately before this one.
    public func previous(calendar: Calendar = .menoGregorian) -> DayWindow {
        let len = count
        let newEnd = start.adding(days: -1, calendar: calendar)
        return DayWindow(lastDays: len, endingOn: newEnd, calendar: calendar)
    }
}
