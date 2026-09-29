import Foundation

/// A deterministic, clearly-labeled example of two weeks of entries, shown to new users as a preview
/// ("See what two weeks looks like"). Never stored and never mixed with real data.
public enum SampleSeries {
    public static func twoWeeks(endingOn today: DayKey = .today(), calendar: Calendar = .menoGregorian) -> InsightInput {
        var surges: [SurgeRecord] = []
        var checkIns: [CheckInRecord] = []
        let pattern = [3, 1, 2, 4, 1, 2, 3, 1, 2, 4, 1, 1, 2, 2]  // surges per day
        let alcohol: Set<Int> = [0, 3, 6, 9]
        for (i, n) in pattern.enumerated() {
            let day = today.adding(days: i - 13, calendar: calendar)
            for k in 0..<n {
                let hour = k == 0 ? 3 : [14, 17, 23][k % 3]
                guard let start = calendar.date(from: DateComponents(year: day.year, month: day.month, day: day.day,
                                                                     hour: hour, minute: 10 + k * 7)) else { continue }
                surges.append(SurgeRecord(kind: hour < 7 || hour >= 21 ? .nightSweat : .hotFlash, startedAt: start,
                                          durationSec: 120 + k * 40, intensity: 2 + (n + k) % 3,
                                          tags: alcohol.contains(i) && k == 0 ? [.alcohol] : (k == 1 ? [.stress] : []),
                                          source: .app))
            }
            checkIns.append(CheckInRecord(day: day, scores: [.sleep: max(3, 8 - n), .mood: max(4, 8 - n / 2), .energy: max(3, 7 - n)],
                                          alcohol: alcohol.contains(i)))
        }
        return InsightInput(surges: surges, checkIns: checkIns)
    }
}
