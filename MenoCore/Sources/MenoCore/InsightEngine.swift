import Foundation

/// Everything the rules can look at. All of it is the user's own entries or their Apple Health data.
public struct InsightInput: Sendable {
    public var surges: [SurgeRecord]
    public var checkIns: [CheckInRecord]
    public var medications: [MedicationRecord]
    public var doses: [DoseRecord]
    public var sleep: [SleepNight]
    public var wristTemp: [WristTempNight]
    public var experiments: [ExperimentRecord]
    /// First day of each period (from Apple Health or the cycle log). Used only for perimenopause users.
    public var cycleStarts: [DayKey]

    public init(surges: [SurgeRecord] = [], checkIns: [CheckInRecord] = [], medications: [MedicationRecord] = [],
                doses: [DoseRecord] = [], sleep: [SleepNight] = [], wristTemp: [WristTempNight] = [],
                experiments: [ExperimentRecord] = [], cycleStarts: [DayKey] = []) {
        self.surges = surges
        self.checkIns = checkIns
        self.medications = medications
        self.doses = doses
        self.sleep = sleep
        self.wristTemp = wristTemp
        self.experiments = experiments
        self.cycleStarts = cycleStarts
    }
}

public enum SleepMeasure: String, Codable, Hashable, Sendable {
    /// Check-in sleep score, 0…10.
    case score
    /// Minutes asleep from Apple Health.
    case healthMinutes
}

/// Which surges an experiment is judged on.
public enum ExperimentMeasure: String, Codable, Hashable, Sendable {
    case nightSurges, allSurges
}

/// Structured result of a rule. The app turns it into localized copy; numbers stay testable here.
/// Copy must say "your entries show", never "means" or "caused".
public enum InsightKind: Hashable, Sendable {
    case sleepAfterHeavyNights(measure: SleepMeasure, heavyNights: Int, heavyAvg: Double, otherNights: Int, otherAvg: Double)
    case alcoholThenSweats(alcoholEvenings: Int, sweatNightsAfterAlcohol: Int, otherEvenings: Int, sweatNightsAfterOther: Int)
    case severityChange(recentAvg: Double, priorAvg: Double, recentCount: Int, priorCount: Int)
    case missedDoses(skippedDays: Int, surgesPerSkippedDay: Double, otherDays: Int, surgesPerOtherDay: Double)
    case peakHour(time: ClockTime, share: Double, total: Int)
    case triggerShare(tag: SurgeTag, share: Double, tagged: Int)
    case wristTempNights(sweatNights: Int, sweatAvgDelta: Double, otherNights: Int, otherAvgDelta: Double)
    case weekdayPattern(weekday: Int, avgOnWeekday: Double, avgOtherDays: Double)
    case treatmentTimeline(medicationID: UUID, medicationName: String, days: Int, beforePerDay: Double, afterPerDay: Double,
                           beforeIntensity: Double?, afterIntensity: Double?)
    case experimentResult(experimentID: UUID, kind: ExperimentKind, measure: ExperimentMeasure,
                          baselineCount: Int, baselineDays: Int, duringCount: Int, duringDays: Int)
    /// Surges per logged day in the 3 days before a period vs all other logged days.
    case cyclePhase(cycles: Int, perDayBefore: Double, perDayOther: Double)
}

public struct Insight: Hashable, Identifiable, Sendable {
    public var ruleID: String
    public var kind: InsightKind
    public var windowDays: Int
    /// Patterns are Pro. The free tier sees that a pattern exists (title slot), not the numbers.
    public var isPremium: Bool
    /// 0…1, used for ordering on Today and picking the top 3 for the PDF.
    public var strength: Double
    public var id: String

    public init(ruleID: String, kind: InsightKind, windowDays: Int, isPremium: Bool = true, strength: Double, id: String? = nil) {
        self.ruleID = ruleID
        self.kind = kind
        self.windowDays = windowDays
        self.isPremium = isPremium
        self.strength = strength
        self.id = id ?? ruleID
    }
}

public enum InsightRuleID {
    public static let sleepAfterHeavyNights = "sleep_after_3plus_surges"
    public static let alcoholThenSweats = "alcohol_then_sweats"
    public static let severityChange = "severity_change"
    public static let missedDoses = "missed_doses_note"
    public static let peakHour = "peak_hour"
    public static let triggerShare = "trigger_share"
    public static let wristTempNights = "wrist_temp_nights"
    public static let weekdayPattern = "weekday_pattern"
    public static let treatmentTimeline = "treatment_timeline"
    public static let experimentResult = "experiment_result"
    public static let cyclePhase = "cycle_phase"
}

/// Local, rule-based pattern finder. No ML, no network. Every rule refuses to speak below its minimum
/// sample size (never fewer than 7 paired days).
public struct InsightEngine: Sendable {
    public static let minPairedDays = 7

    public var calendar: Calendar

    public init(calendar: Calendar = .menoGregorian) {
        self.calendar = calendar
    }

    public func compute(_ input: InsightInput, today: DayKey) -> [Insight] {
        var out: [Insight] = []
        out += [sleepAfterHeavyNights(input, today: today)].compactMap { $0 }
        out += [alcoholThenSweats(input, today: today)].compactMap { $0 }
        out += [severityChange(input, today: today)].compactMap { $0 }
        out += [missedDoses(input, today: today)].compactMap { $0 }
        out += [peakHour(input, today: today)].compactMap { $0 }
        out += [triggerShare(input, today: today)].compactMap { $0 }
        out += [wristTempNights(input, today: today)].compactMap { $0 }
        out += [weekdayPattern(input, today: today)].compactMap { $0 }
        out += treatmentTimeline(input, today: today)
        out += experimentResults(input, today: today)
        out += [cyclePhase(input, today: today)].compactMap { $0 }
        return out.sorted { $0.strength > $1.strength }
    }

    // MARK: - Helpers

    private func loggedDays(_ input: InsightInput) -> Set<DayKey> {
        Set(input.surges.map { DayKey($0.startedAt, calendar: calendar) }).union(input.checkIns.map(\.day))
    }

    private func isNightSurge(_ s: SurgeRecord) -> Bool {
        s.kind == .nightSweat || s.isNight(calendar: calendar)
    }

    private func mean(_ values: [Double]) -> Double {
        values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
    }

    private func round1(_ v: Double) -> Double { (v * 10).rounded() / 10 }

    // MARK: - Rules

    /// "On N nights with 3+ surges, average sleep score was X vs Y on other nights."
    func sleepAfterHeavyNights(_ input: InsightInput, today: DayKey) -> Insight? {
        let window = DayWindow(lastDays: 14, endingOn: today, calendar: calendar)
        let surgesByNight = Dictionary(grouping: input.surges) { $0.nightKey(calendar: calendar) }

        func evaluate(_ pairs: [(DayKey, Double)], measure: SleepMeasure) -> Insight? {
            guard pairs.count >= Self.minPairedDays else { return nil }
            let heavy = pairs.filter { (surgesByNight[$0.0]?.count ?? 0) >= 3 }
            let other = pairs.filter { (surgesByNight[$0.0]?.count ?? 0) < 3 }
            guard heavy.count >= 2, other.count >= 2 else { return nil }
            let h = mean(heavy.map(\.1)), o = mean(other.map(\.1))
            let scale = measure == .score ? 10.0 : 480.0
            return Insight(ruleID: InsightRuleID.sleepAfterHeavyNights,
                           kind: .sleepAfterHeavyNights(measure: measure, heavyNights: heavy.count, heavyAvg: round1(h),
                                                        otherNights: other.count, otherAvg: round1(o)),
                           windowDays: 14, strength: min(abs(o - h) / scale * 2, 1))
        }

        let scorePairs: [(DayKey, Double)] = input.checkIns.compactMap { c in
            guard window.contains(c.day), let s = c.scores[.sleep] else { return nil }
            return (c.day, Double(s))
        }
        if let i = evaluate(scorePairs, measure: .score) { return i }
        let minutePairs: [(DayKey, Double)] = input.sleep.compactMap { n in
            window.contains(n.morning) && n.minutesAsleep > 0 ? (n.morning, Double(n.minutesAsleep)) : nil
        }
        return evaluate(minutePairs, measure: .healthMinutes)
    }

    /// "On N evenings marked alcohol, night sweats were logged M times" — compared with other evenings.
    func alcoholThenSweats(_ input: InsightInput, today: DayKey) -> Insight? {
        // Evenings whose following night is complete: window ends yesterday.
        let window = DayWindow(lastDays: 14, endingOn: today.adding(days: -1, calendar: calendar), calendar: calendar)
        let nightsWithSweats = Set(input.surges.filter(isNightSurge).map { $0.nightKey(calendar: calendar) })
        let answered = input.checkIns.filter { window.contains($0.day) && $0.alcohol != nil }
        guard answered.count >= Self.minPairedDays else { return nil }
        let yes = answered.filter { $0.alcohol == true }
        let no = answered.filter { $0.alcohol == false }
        guard yes.count >= 2, no.count >= 2 else { return nil }
        let sweatYes = yes.filter { nightsWithSweats.contains($0.day.adding(days: 1, calendar: calendar)) }.count
        let sweatNo = no.filter { nightsWithSweats.contains($0.day.adding(days: 1, calendar: calendar)) }.count
        let rateYes = Double(sweatYes) / Double(yes.count), rateNo = Double(sweatNo) / Double(no.count)
        return Insight(ruleID: InsightRuleID.alcoholThenSweats,
                       kind: .alcoholThenSweats(alcoholEvenings: yes.count, sweatNightsAfterAlcohol: sweatYes,
                                                otherEvenings: no.count, sweatNightsAfterOther: sweatNo),
                       windowDays: 14, strength: min(abs(rateYes - rateNo), 1))
    }

    /// "Average surge intensity was A in the last 30 days vs B in the 30 before."
    func severityChange(_ input: InsightInput, today: DayKey) -> Insight? {
        let recent = DayWindow(lastDays: 30, endingOn: today, calendar: calendar)
        let prior = recent.previous(calendar: calendar)
        let r = input.surges.filter { recent.contains(DayKey($0.startedAt, calendar: calendar)) }.compactMap(\.intensity)
        let p = input.surges.filter { prior.contains(DayKey($0.startedAt, calendar: calendar)) }.compactMap(\.intensity)
        guard r.count >= Self.minPairedDays, p.count >= Self.minPairedDays else { return nil }
        let ra = mean(r.map(Double.init)), pa = mean(p.map(Double.init))
        guard abs(ra - pa) >= 0.3 else { return nil }
        return Insight(ruleID: InsightRuleID.severityChange,
                       kind: .severityChange(recentAvg: round1(ra), priorAvg: round1(pa), recentCount: r.count, priorCount: p.count),
                       windowDays: 60, strength: min(abs(ra - pa) / 2, 1))
    }

    /// Only when both skipped doses and surges exist. Correlation wording only.
    func missedDoses(_ input: InsightInput, today: DayKey) -> Insight? {
        let window = DayWindow(lastDays: 14, endingOn: today, calendar: calendar)
        let doseDays = Dictionary(grouping: input.doses.filter { window.contains(DayKey($0.at, calendar: calendar)) }) {
            DayKey($0.at, calendar: calendar)
        }
        guard doseDays.count >= Self.minPairedDays else { return nil }
        let skipped = doseDays.filter { $0.value.contains(where: \.skipped) }.map(\.key)
        let taken = doseDays.filter { !$0.value.contains(where: \.skipped) }.map(\.key)
        guard skipped.count >= 2, taken.count >= 2 else { return nil }
        let perDay = Dictionary(grouping: input.surges) { DayKey($0.startedAt, calendar: calendar) }.mapValues(\.count)
        guard !input.surges.isEmpty else { return nil }
        let s = mean(skipped.map { Double(perDay[$0] ?? 0) }), t = mean(taken.map { Double(perDay[$0] ?? 0) })
        return Insight(ruleID: InsightRuleID.missedDoses,
                       kind: .missedDoses(skippedDays: skipped.count, surgesPerSkippedDay: round1(s),
                                          otherDays: taken.count, surgesPerOtherDay: round1(t)),
                       windowDays: 14, strength: min(abs(s - t) / 3, 1) * 0.8)
    }

    /// "Your surges cluster around 3:12am." Needs 10+ surges in 30 days and a peak holding 20%+.
    func peakHour(_ input: InsightInput, today: DayKey) -> Insight? {
        let window = DayWindow(lastDays: 30, endingOn: today, calendar: calendar)
        let stats = StatsCalculator.compute(window: window, surges: input.surges, checkIns: [], calendar: calendar)
        guard stats.total >= 10, let peak = stats.peakTime else { return nil }
        let share = Double(stats.hourHistogram[peak.hour]) / Double(stats.total)
        guard share >= 0.2 else { return nil }
        return Insight(ruleID: InsightRuleID.peakHour, kind: .peakHour(time: peak, share: round2(share), total: stats.total),
                       windowDays: 30, strength: min(share * 1.5, 1) * 0.7)
    }

    /// "Alcohol was tagged on 38% of tagged surges." Needs 10+ tagged surges; top tag holds 25%+.
    func triggerShare(_ input: InsightInput, today: DayKey) -> Insight? {
        let window = DayWindow(lastDays: 30, endingOn: today, calendar: calendar)
        let tagged = input.surges.filter {
            window.contains(DayKey($0.startedAt, calendar: calendar)) && $0.tags.contains { $0 != .unknown }
        }
        guard tagged.count >= 10 else { return nil }
        var counts: [SurgeTag: Int] = [:]
        for s in tagged { for t in Set(s.tags) where t != .unknown { counts[t, default: 0] += 1 } }
        guard let top = counts.max(by: { $0.value != $1.value ? $0.value < $1.value : $0.key.rawValue > $1.key.rawValue }) else { return nil }
        let share = Double(top.value) / Double(tagged.count)
        guard share >= 0.25 else { return nil }
        return Insight(ruleID: InsightRuleID.triggerShare, kind: .triggerShare(tag: top.key, share: round2(share), tagged: tagged.count),
                       windowDays: 30, strength: min(share, 1) * 0.8)
    }

    /// Wrist temperature (Apple Health) on nights with vs without logged night surges. Context, never detection.
    func wristTempNights(_ input: InsightInput, today: DayKey) -> Insight? {
        let window = DayWindow(lastDays: 30, endingOn: today, calendar: calendar)
        let temps = input.wristTemp.filter { window.contains($0.morning) }
        guard temps.count >= Self.minPairedDays else { return nil }
        let sweatNights = Set(input.surges.filter(isNightSurge).map { $0.nightKey(calendar: calendar) })
        let yes = temps.filter { sweatNights.contains($0.morning) }
        let no = temps.filter { !sweatNights.contains($0.morning) }
        guard yes.count >= 2, no.count >= 2 else { return nil }
        let y = mean(yes.map(\.deviationCelsius)), n = mean(no.map(\.deviationCelsius))
        return Insight(ruleID: InsightRuleID.wristTempNights,
                       kind: .wristTempNights(sweatNights: yes.count, sweatAvgDelta: round2(y), otherNights: no.count, otherAvgDelta: round2(n)),
                       windowDays: 30, strength: min(abs(y - n), 1) * 0.6)
    }

    /// A weekday that runs hotter than the rest. Needs 8 weeks and 3+ logged occurrences of that weekday.
    func weekdayPattern(_ input: InsightInput, today: DayKey) -> Insight? {
        let window = DayWindow(lastDays: 56, endingOn: today, calendar: calendar)
        let logged = loggedDays(input).filter { window.contains($0) }
        guard logged.count >= 28 else { return nil }
        let perDay = Dictionary(grouping: input.surges) { DayKey($0.startedAt, calendar: calendar) }.mapValues(\.count)
        let byWeekday = Dictionary(grouping: logged) { $0.weekday(calendar: calendar) }
        var best: (Int, Double, Double)?
        for (wd, days) in byWeekday where days.count >= 3 {
            let avg = mean(days.map { Double(perDay[$0] ?? 0) })
            let others = logged.filter { $0.weekday(calendar: calendar) != wd }
            let otherAvg = mean(others.map { Double(perDay[$0] ?? 0) })
            guard otherAvg > 0, avg >= otherAvg * 1.5, avg - otherAvg >= 0.5 else { continue }
            if let b = best, avg / otherAvg <= b.1 / max(b.2, 0.01) { continue }
            best = (wd, avg, otherAvg)
        }
        guard let b = best else { return nil }
        return Insight(ruleID: InsightRuleID.weekdayPattern,
                       kind: .weekdayPattern(weekday: b.0, avgOnWeekday: round1(b.1), avgOtherDays: round1(b.2)),
                       windowDays: 56, strength: min((b.1 / b.2 - 1) / 2, 1) * 0.5)
    }

    /// Before vs after a medication the user added. Always a "coincidence check" in copy.
    public func treatmentTimeline(_ input: InsightInput, today: DayKey) -> [Insight] {
        let logged = loggedDays(input)
        let perDay = Dictionary(grouping: input.surges) { DayKey($0.startedAt, calendar: calendar) }
        var out: [Insight] = []
        for med in input.medications {
            let start = DayKey(med.startDate, calendar: calendar)
            let daysSince = start.days(to: today, calendar: calendar)
            guard daysSince >= 14, daysSince <= 180 else { continue }
            let len = min(30, daysSince)
            let after = DayWindow(start: start, end: start.adding(days: len - 1, calendar: calendar))
            let before = DayWindow(lastDays: len, endingOn: start.adding(days: -1, calendar: calendar), calendar: calendar)
            let aDays = logged.filter { after.contains($0) }, bDays = logged.filter { before.contains($0) }
            guard aDays.count >= Self.minPairedDays, bDays.count >= Self.minPairedDays else { continue }
            let aPer = mean(aDays.map { Double(perDay[$0]?.count ?? 0) })
            let bPer = mean(bDays.map { Double(perDay[$0]?.count ?? 0) })
            let aInt = aDays.flatMap { perDay[$0] ?? [] }.compactMap(\.intensity)
            let bInt = bDays.flatMap { perDay[$0] ?? [] }.compactMap(\.intensity)
            out.append(Insight(
                ruleID: InsightRuleID.treatmentTimeline,
                kind: .treatmentTimeline(medicationID: med.id, medicationName: med.name, days: len,
                                         beforePerDay: round1(bPer), afterPerDay: round1(aPer),
                                         beforeIntensity: bInt.isEmpty ? nil : round1(mean(bInt.map(Double.init))),
                                         afterIntensity: aInt.isEmpty ? nil : round1(mean(aInt.map(Double.init)))),
                windowDays: len * 2,
                strength: min(abs(bPer - aPer) / max(bPer, 1), 1) * 0.9,
                id: "\(InsightRuleID.treatmentTimeline)-\(med.id.uuidString)"))
        }
        return out
    }

    /// Finished experiments: the experiment window vs the same number of days just before it.
    public func experimentResults(_ input: InsightInput, today: DayKey) -> [Insight] {
        let logged = loggedDays(input)
        var out: [Insight] = []
        for e in input.experiments where e.isFinished(today: today) {
            let measure: ExperimentMeasure = e.kind == .noCaffeineAfterNoon || e.kind == .custom ? .allSurges : .nightSurges
            let relevant = measure == .nightSurges ? input.surges.filter(isNightSurge) : input.surges
            func dayOf(_ s: SurgeRecord) -> DayKey {
                measure == .nightSurges ? s.nightKey(calendar: calendar) : DayKey(s.startedAt, calendar: calendar)
            }
            let bDays = logged.filter { e.baseline.contains($0) }.count
            let dDays = logged.filter { e.window.contains($0) }.count
            guard bDays >= Self.minPairedDays, dDays >= Self.minPairedDays else { continue }
            let b = relevant.filter { e.baseline.contains(dayOf($0)) }.count
            let d = relevant.filter { e.window.contains(dayOf($0)) }.count
            let bRate = Double(b) / Double(bDays), dRate = Double(d) / Double(dDays)
            out.append(Insight(
                ruleID: InsightRuleID.experimentResult,
                kind: .experimentResult(experimentID: e.id, kind: e.kind, measure: measure,
                                        baselineCount: b, baselineDays: bDays, duringCount: d, duringDays: dDays),
                windowDays: e.lengthDays * 2,
                strength: 0.95 + min(abs(bRate - dRate), 0.05),
                id: "\(InsightRuleID.experimentResult)-\(e.id.uuidString)"))
        }
        return out
    }

    /// "Your surges cluster in the 3 days before your period." Needs 2+ period starts in 120 days,
    /// 20+ logged days, and the pre-period days running at least 1.5x the rest.
    func cyclePhase(_ input: InsightInput, today: DayKey) -> Insight? {
        let window = DayWindow(lastDays: 120, endingOn: today, calendar: calendar)
        let starts = Set(input.cycleStarts.filter { window.contains($0) })
        guard starts.count >= 2 else { return nil }
        let logged = loggedDays(input).filter { window.contains($0) }
        guard logged.count >= 20 else { return nil }
        var before = Set<DayKey>()
        for s in starts { for k in 1...3 { before.insert(s.adding(days: -k, calendar: calendar)) } }
        let perDay = Dictionary(grouping: input.surges) { DayKey($0.startedAt, calendar: calendar) }.mapValues(\.count)
        let b = logged.filter { before.contains($0) }, o = logged.filter { !before.contains($0) }
        guard b.count >= 4, o.count >= Self.minPairedDays else { return nil }
        let bAvg = mean(b.map { Double(perDay[$0] ?? 0) }), oAvg = mean(o.map { Double(perDay[$0] ?? 0) })
        guard oAvg > 0 ? bAvg >= oAvg * 1.5 : bAvg >= 1 else { return nil }
        return Insight(ruleID: InsightRuleID.cyclePhase,
                       kind: .cyclePhase(cycles: starts.count, perDayBefore: round1(bAvg), perDayOther: round1(oAvg)),
                       windowDays: 120, strength: min((bAvg - oAvg) / max(oAvg, 1), 1) * 0.85)
    }

    /// Tonight's heads-up: the user marked alcohol today and, on past alcohol evenings, night sweats followed
    /// at least 60% of the time (from `alcoholThenSweats`). Nil otherwise. Wording: her entries, not a forecast.
    public func tonightHeadsUp(_ input: InsightInput, today: DayKey) -> (alcoholEvenings: Int, sweatNights: Int)? {
        guard input.checkIns.first(where: { $0.day == today })?.alcohol == true,
              let i = alcoholThenSweats(input, today: today),
              case let .alcoholThenSweats(yes, sweatYes, _, _) = i.kind,
              yes >= 3, Double(sweatYes) / Double(yes) >= 0.6 else { return nil }
        return (yes, sweatYes)
    }

    private func round2(_ v: Double) -> Double { (v * 100).rounded() / 100 }
}
