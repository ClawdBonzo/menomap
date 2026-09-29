import XCTest
@testable import MenoCore

final class DayKeyTests: XCTestCase {
    private func cal(_ tz: String) -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: tz)!
        return c
    }

    func testWindowsUseCalendarDaysAcrossSpringForward() {
        // US DST began 2026-03-08. A 7-day window ending the 10th must still hold 7 distinct days.
        let c = cal("America/New_York")
        let end = DayKey(year: 2026, month: 3, day: 10)
        let w = DayWindow(lastDays: 7, endingOn: end, calendar: c)
        XCTAssertEqual(w.start, DayKey(year: 2026, month: 3, day: 4))
        XCTAssertEqual(w.days(calendar: c).count, 7)
        XCTAssertEqual(Set(w.days(calendar: c)).count, 7)
    }

    func testWindowsUseCalendarDaysAcrossFallBack() {
        let c = cal("Europe/London") // BST ended 2026-10-25
        let w = DayWindow(lastDays: 30, endingOn: DayKey(year: 2026, month: 11, day: 5), calendar: c)
        XCTAssertEqual(w.days(calendar: c).count, 30)
        XCTAssertEqual(w.start, DayKey(year: 2026, month: 10, day: 7))
    }

    func testNinetyDayWindowAndPrevious() {
        let end = DayKey(year: 2026, month: 9, day: 29)
        let w = DayWindow(lastDays: 90, endingOn: end)
        XCTAssertEqual(w.count, 90)
        let p = w.previous()
        XCTAssertEqual(p.count, 90)
        XCTAssertEqual(p.end.adding(days: 1), w.start)
    }

    func testDayKeyIgnoresDeviceCalendar() {
        var buddhist = Calendar(identifier: .buddhist)
        buddhist.timeZone = TimeZone(identifier: "UTC")!
        var greg = Calendar.menoGregorian
        greg.timeZone = TimeZone(identifier: "UTC")!
        let date = Date(timeIntervalSince1970: 1_790_000_000)
        XCTAssertEqual(DayKey(date, calendar: greg).year, 2026)
    }

    func testNightKeyAssignsEarlyMorningToSameDay() {
        let c = Calendar.menoGregorian
        let threeAM = c.date(from: DateComponents(year: 2026, month: 9, day: 10, hour: 3))!
        let elevenPM = c.date(from: DateComponents(year: 2026, month: 9, day: 10, hour: 23))!
        let s1 = SurgeRecord(kind: .nightSweat, startedAt: threeAM, durationSec: 120, intensity: 3, source: .app)
        let s2 = SurgeRecord(kind: .nightSweat, startedAt: elevenPM, durationSec: 120, intensity: 3, source: .app)
        XCTAssertEqual(s1.nightKey(), DayKey(year: 2026, month: 9, day: 10))
        XCTAssertEqual(s2.nightKey(), DayKey(year: 2026, month: 9, day: 11))
        XCTAssertTrue(s1.isNight())
    }
}

/// Builds fixture series anchored on a fixed "today".
private struct Fixture {
    let cal = Calendar.menoGregorian
    let today = DayKey(year: 2026, month: 9, day: 29)

    func date(_ day: DayKey, hour: Int, minute: Int = 0) -> Date {
        cal.date(from: DateComponents(year: day.year, month: day.month, day: day.day, hour: hour, minute: minute))!
    }

    func day(_ offset: Int) -> DayKey { today.adding(days: offset) }

    func surge(_ offset: Int, hour: Int, minute: Int = 0, kind: SurgeKind = .hotFlash, intensity: Int? = 3,
               tags: [SurgeTag] = []) -> SurgeRecord {
        SurgeRecord(kind: kind, startedAt: date(day(offset), hour: hour, minute: minute), durationSec: 150,
                    intensity: intensity, tags: tags, source: .app)
    }
}

final class InsightEngineTests: XCTestCase {
    private let f = Fixture()
    private let engine = InsightEngine()

    func testEmptyInputProducesNoInsights() {
        XCTAssertTrue(engine.compute(InsightInput(), today: f.today).isEmpty)
    }

    // MARK: sleep_after_3plus_surges

    func testSleepRuleNeedsSevenPairedDays() {
        var surges: [SurgeRecord] = []
        var checkIns: [CheckInRecord] = []
        for o in -5...0 { // only 6 days
            checkIns.append(CheckInRecord(day: f.day(o), scores: [.sleep: o % 2 == 0 ? 4 : 8]))
            if o % 2 == 0 { surges += (0..<3).map { _ in f.surge(o, hour: 2, kind: .nightSweat) } }
        }
        XCTAssertNil(engine.sleepAfterHeavyNights(InsightInput(surges: surges, checkIns: checkIns), today: f.today))
    }

    func testSleepRuleWithFourteenDayFixture() {
        var surges: [SurgeRecord] = []
        var checkIns: [CheckInRecord] = []
        for o in -13...0 {
            let heavy = o % 3 == 0 // offsets 0, -3, -6, -9, -12 → 5 heavy nights
            checkIns.append(CheckInRecord(day: f.day(o), scores: [.sleep: heavy ? 4 : 7]))
            if heavy { surges += (0..<3).map { i in f.surge(o, hour: 1 + i, kind: .nightSweat) } }
        }
        let i = engine.sleepAfterHeavyNights(InsightInput(surges: surges, checkIns: checkIns), today: f.today)
        guard case .sleepAfterHeavyNights(let measure, let heavyN, let heavyAvg, let otherN, let otherAvg)? = i?.kind else {
            return XCTFail("expected insight")
        }
        XCTAssertEqual(measure, .score)
        XCTAssertEqual(heavyN, 5)
        XCTAssertEqual(heavyAvg, 4.0)
        XCTAssertEqual(otherN, 9)
        XCTAssertEqual(otherAvg, 7.0)
    }

    func testSleepRuleFallsBackToHealthMinutes() {
        var surges: [SurgeRecord] = []
        var sleep: [SleepNight] = []
        for o in -9...0 {
            let heavy = o >= -2
            sleep.append(SleepNight(morning: f.day(o), minutesAsleep: heavy ? 300 : 420))
            if heavy { surges += (0..<4).map { i in f.surge(o, hour: 2 + i, kind: .nightSweat) } }
        }
        let i = engine.sleepAfterHeavyNights(InsightInput(surges: surges, sleep: sleep), today: f.today)
        guard case .sleepAfterHeavyNights(let measure, 3, 300, 7, 420)? = i?.kind else {
            return XCTFail("expected minutes insight, got \(String(describing: i))")
        }
        XCTAssertEqual(measure, .healthMinutes)
    }

    // MARK: alcohol_then_sweats

    func testAlcoholRuleCountsFollowingNights() {
        var surges: [SurgeRecord] = []
        var checkIns: [CheckInRecord] = []
        // Evenings -14…-1; alcohol on -10, -7, -4, -2. Sweats the following nights (3am next day) for 3 of them.
        let alcoholDays: Set<Int> = [-10, -7, -4, -2]
        for o in -14 ... -1 {
            checkIns.append(CheckInRecord(day: f.day(o), scores: [:], alcohol: alcoholDays.contains(o)))
        }
        for o in [-10, -7, -4] { surges.append(f.surge(o + 1, hour: 3, kind: .nightSweat)) }
        surges.append(f.surge(-12 + 1, hour: 3, kind: .nightSweat)) // one after a dry evening
        let i = engine.alcoholThenSweats(InsightInput(surges: surges, checkIns: checkIns), today: f.today)
        guard case .alcoholThenSweats(let yes, let sweatYes, let no, let sweatNo)? = i?.kind else {
            return XCTFail("expected insight")
        }
        XCTAssertEqual(yes, 4)
        XCTAssertEqual(sweatYes, 3)
        XCTAssertEqual(no, 10)
        XCTAssertEqual(sweatNo, 1)
    }

    func testAlcoholRuleSilentWithoutEnoughAnswers() {
        let checkIns = (-5 ... -1).map { CheckInRecord(day: f.day($0), scores: [:], alcohol: $0 % 2 == 0) }
        XCTAssertNil(engine.alcoholThenSweats(InsightInput(checkIns: checkIns), today: f.today))
    }

    // MARK: severity_change

    func testSeverityChange() {
        var surges: [SurgeRecord] = []
        for o in -59 ... -30 where o % 3 == 0 { surges.append(f.surge(o, hour: 14, intensity: 4)) } // prior
        for o in -29 ... 0 where o % 3 == 0 { surges.append(f.surge(o, hour: 14, intensity: 2)) } // recent
        let i = engine.severityChange(InsightInput(surges: surges), today: f.today)
        guard case .severityChange(let r, let p, let rc, let pc)? = i?.kind else { return XCTFail("expected insight") }
        XCTAssertEqual(r, 2.0)
        XCTAssertEqual(p, 4.0)
        XCTAssertEqual(rc, 10)
        XCTAssertEqual(pc, 10)
    }

    func testSeverityChangeNeedsSevenRatedEachSide() {
        let surges = (-40 ... 0).filter { $0 % 7 == 0 }.map { f.surge($0, hour: 12, intensity: $0 < -29 ? 5 : 1) }
        XCTAssertNil(engine.severityChange(InsightInput(surges: surges), today: f.today))
    }

    // MARK: missed_doses_note

    func testMissedDosesNeedsBothDosesAndSurges() {
        let med = UUID()
        let doses = (-9...0).map { DoseRecord(medicationID: med, at: f.date(f.day($0), hour: 8), skipped: $0 % 4 == 0) }
        XCTAssertNil(engine.missedDoses(InsightInput(doses: doses), today: f.today), "no surges → silent")
        let surges = [-8, -4, -4, 0, 0, 0].map { f.surge($0, hour: 15) }
        let i = engine.missedDoses(InsightInput(surges: surges, doses: doses), today: f.today)
        guard case .missedDoses(let sd, let sp, let od, let op)? = i?.kind else { return XCTFail("expected insight") }
        XCTAssertEqual(sd, 3) // -8, -4, 0
        XCTAssertEqual(sp, 2.0) // (1+2+3)/3
        XCTAssertEqual(od, 7)
        XCTAssertEqual(op, 0.0)
    }

    // MARK: peak_hour / trigger_share

    func testPeakHour() {
        var surges = (0..<6).map { f.surge(-$0, hour: 3, minute: 10 + $0) }
        surges += (0..<5).map { f.surge(-$0, hour: 15) }
        let i = engine.peakHour(InsightInput(surges: surges), today: f.today)
        guard case .peakHour(let t, let share, let total)? = i?.kind else { return XCTFail("expected insight") }
        XCTAssertEqual(t.hour, 3)
        XCTAssertEqual(t.minute, 13)
        XCTAssertEqual(total, 11)
        XCTAssertEqual(share, 0.55)
    }

    func testPeakHourNeedsTenSurges() {
        let surges = (0..<9).map { f.surge(-$0, hour: 3) }
        XCTAssertNil(engine.peakHour(InsightInput(surges: surges), today: f.today))
    }

    func testTriggerShareIgnoresUnknown() {
        var surges = (0..<5).map { f.surge(-$0, hour: 20, tags: [.alcohol]) }
        surges += (0..<3).map { f.surge(-$0, hour: 10, tags: [.stress]) }
        surges += (0..<2).map { f.surge(-$0, hour: 11, tags: [.heat, .unknown]) }
        surges += (0..<4).map { f.surge(-$0, hour: 12, tags: [.unknown]) }
        let i = engine.triggerShare(InsightInput(surges: surges), today: f.today)
        guard case .triggerShare(let tag, let share, let tagged)? = i?.kind else { return XCTFail("expected insight") }
        XCTAssertEqual(tag, .alcohol)
        XCTAssertEqual(tagged, 10)
        XCTAssertEqual(share, 0.5)
    }

    // MARK: wrist temp, weekday, treatment, experiments

    func testWristTempNights() {
        var temps: [WristTempNight] = []
        var surges: [SurgeRecord] = []
        for o in -9...0 {
            let sweat = o % 2 == 0
            temps.append(WristTempNight(morning: f.day(o), deviationCelsius: sweat ? 0.5 : 0.1))
            if sweat { surges.append(f.surge(o, hour: 2, kind: .nightSweat)) }
        }
        let i = engine.wristTempNights(InsightInput(surges: surges, wristTemp: temps), today: f.today)
        guard case .wristTempNights(5, 0.5, 5, 0.1)? = i?.kind else { return XCTFail("got \(String(describing: i))") }
    }

    func testWeekdayPattern() {
        var surges: [SurgeRecord] = []
        var checkIns: [CheckInRecord] = []
        for o in -55...0 {
            let d = f.day(o)
            checkIns.append(CheckInRecord(day: d, scores: [.mood: 5]))
            let n = d.weekday() == 2 ? 4 : 1 // Mondays run hot
            surges += (0..<n).map { i in f.surge(o, hour: 9 + i) }
        }
        let i = engine.weekdayPattern(InsightInput(surges: surges, checkIns: checkIns), today: f.today)
        guard case .weekdayPattern(let wd, let a, let b)? = i?.kind else { return XCTFail("expected insight") }
        XCTAssertEqual(wd, 2)
        XCTAssertEqual(a, 4.0)
        XCTAssertEqual(b, 1.0)
    }

    func testTreatmentTimeline() {
        let start = f.date(f.day(-20), hour: 9)
        let med = MedicationRecord(name: "Estradiol gel", category: .estrogen, startDate: start)
        var surges: [SurgeRecord] = []
        for o in -40 ... -21 { surges += [f.surge(o, hour: 10, intensity: 4), f.surge(o, hour: 16, intensity: 4)] }
        for o in -20 ... -1 where o % 2 == 0 { surges.append(f.surge(o, hour: 10, intensity: 2)) }
        let checkIns = (-20 ... -1).map { CheckInRecord(day: f.day($0), scores: [.mood: 6]) }
        let out = engine.treatmentTimeline(InsightInput(surges: surges, checkIns: checkIns, medications: [med]), today: f.today)
        XCTAssertEqual(out.count, 1)
        guard case .treatmentTimeline(_, let name, let days, let before, let after, let bi, let ai) = out[0].kind else {
            return XCTFail("expected insight")
        }
        XCTAssertEqual(name, "Estradiol gel")
        XCTAssertEqual(days, 20)
        XCTAssertEqual(before, 2.0)
        XCTAssertEqual(after, 0.5)
        XCTAssertEqual(bi, 4.0)
        XCTAssertEqual(ai, 2.0)
    }

    func testTreatmentTimelineWaitsFourteenDays() {
        let med = MedicationRecord(name: "X", category: .other, startDate: f.date(f.day(-10), hour: 9))
        let surges = (-40...0).map { f.surge($0, hour: 10) }
        XCTAssertTrue(engine.treatmentTimeline(InsightInput(surges: surges, medications: [med]), today: f.today).isEmpty)
    }

    func testExperimentResult() {
        let e = ExperimentRecord(kind: .noAlcoholAfter7, startDay: f.day(-14), lengthDays: 14) // -14…-1
        var surges: [SurgeRecord] = []
        for o in -28 ... -15 { surges.append(f.surge(o, hour: 2, kind: .nightSweat)) } // 14 baseline nights
        for o in -14 ... -1 where o % 2 == 0 { surges.append(f.surge(o, hour: 2, kind: .nightSweat)) } // 7 during
        let checkIns = (-28 ... -1).map { CheckInRecord(day: f.day($0), scores: [.sleep: 6]) }
        let out = engine.experimentResults(InsightInput(surges: surges, checkIns: checkIns, experiments: [e]), today: f.today)
        guard case .experimentResult(_, .noAlcoholAfter7, .nightSurges, let b, 14, let d, 14)? = out.first?.kind else {
            return XCTFail("got \(out)")
        }
        XCTAssertEqual(b, 14)
        XCTAssertEqual(d, 7)
    }

    func testUnfinishedExperimentIsSilent() {
        let e = ExperimentRecord(kind: .coolerBedroom, startDay: f.day(-5))
        XCTAssertTrue(engine.experimentResults(InsightInput(experiments: [e]), today: f.today).isEmpty)
    }
}

final class StatsTests: XCTestCase {
    private let f = Fixture()

    func testHeatScale() {
        XCTAssertEqual(HeatScale.level(forLoad: 0), 0)
        XCTAssertEqual(HeatScale.level(forLoad: 3), 1)
        XCTAssertEqual(HeatScale.level(forLoad: 6), 2)
        XCTAssertEqual(HeatScale.level(forLoad: 10), 3)
        XCTAssertEqual(HeatScale.level(forLoad: 15), 4)
        XCTAssertEqual(HeatScale.level(forLoad: 40), 5)
    }

    func testSevenDayStats() {
        let surges = [
            f.surge(0, hour: 3, kind: .nightSweat, intensity: 5),
            f.surge(0, hour: 14, intensity: nil),
            f.surge(-2, hour: 23, kind: .hotFlash, intensity: 2),
            f.surge(-9, hour: 12), // outside the window
        ]
        let checkIns = [CheckInRecord(day: f.day(-4), scores: [.sleep: 6])]
        let s = StatsCalculator.compute(window: DayWindow(lastDays: 7, endingOn: f.today), surges: surges, checkIns: checkIns)
        XCTAssertEqual(s.total, 3)
        XCTAssertEqual(s.nightSweats, 1)
        XCTAssertEqual(s.nightSurges, 2)
        XCTAssertEqual(s.rated, 2)
        XCTAssertEqual(s.avgIntensity, 3.5)
        XCTAssertEqual(s.days.count, 7)
        XCTAssertEqual(s.days.last?.count, 2)
        XCTAssertEqual(s.days.last?.level, 3) // load 5 + 3 = 8
        XCTAssertEqual(s.loggedDays, 3)
        XCTAssertEqual(s.calmestDay, f.day(-4)) // logged via check-in, zero surges
        XCTAssertEqual(s.longestCalmStretch, 2) // -4 and -3
    }

    func testCheckInCustomizationKeepsHistory() {
        // Old check-ins scored brain fog; the user has since switched it off. Averages still see it.
        let old = CheckInRecord(day: f.day(-3), scores: [.brainFog: 7, .sleep: 5])
        let new = CheckInRecord(day: f.day(-1), scores: [.sleep: 7])
        let avg = StatsCalculator.checkInAverages(window: DayWindow(lastDays: 7, endingOn: f.today), checkIns: [old, new])
        XCTAssertEqual(avg[.brainFog]?.avg, 7)
        XCTAssertEqual(avg[.sleep]?.avg, 6)
        XCTAssertEqual(avg[.sleep]?.n, 2)
    }

    func testReadiness() {
        let empty = VisitReadiness.compute(loggedDaysLast30: 0, surgesLast30: 0, checkInsLast30: 0, medicationsDone: false, questionsPicked: 0)
        XCTAssertEqual(empty.score, 0)
        XCTAssertEqual(empty.gaps.count, 5)
        let full = VisitReadiness.compute(loggedDaysLast30: 20, surgesLast30: 9, checkInsLast30: 12, medicationsDone: true, questionsPicked: 3)
        XCTAssertEqual(full.score, 1)
        XCTAssertTrue(full.gaps.isEmpty)
        let half = VisitReadiness.compute(loggedDaysLast30: 7, surgesLast30: 5, checkInsLast30: 0, medicationsDone: true, questionsPicked: 0)
        XCTAssertEqual(half.score, 0.45)
    }
}

final class SharedTests: XCTestCase {
    func testSeverityMapping() {
        XCTAssertEqual(HealthSeverity(intensity: 1), .mild)
        XCTAssertEqual(HealthSeverity(intensity: 2), .mild)
        XCTAssertEqual(HealthSeverity(intensity: 3), .moderate)
        XCTAssertEqual(HealthSeverity(intensity: 4), .moderate)
        XCTAssertEqual(HealthSeverity(intensity: 5), .severe)
        XCTAssertEqual(HealthSeverity(intensity: nil), .unspecified)
        XCTAssertEqual(HealthSeverity.severe.intensity, 5)
        XCTAssertNil(HealthSeverity.notPresent.intensity)
    }

    func testWatchMessageRoundTrip() {
        let r = SurgeRecord(kind: .nightSweat, startedAt: Date(timeIntervalSince1970: 1_790_000_000), durationSec: 95,
                            intensity: nil, source: .watch)
        let msg = WatchMessage.surge(r)
        XCTAssertEqual(WatchMessage(userInfo: msg.userInfo()), msg)
    }

    func testPaperSizeAndEmergency() {
        XCTAssertEqual(RegionInfo.paperSize(regionCode: "US"), .letter)
        XCTAssertEqual(RegionInfo.paperSize(regionCode: "GB"), .a4)
        XCTAssertEqual(RegionInfo.paperSize(regionCode: nil), .a4)
        XCTAssertEqual(RegionInfo.emergencyNumber(regionCode: "au"), "000")
        XCTAssertNil(RegionInfo.emergencyNumber(regionCode: "ZZ"))
    }

    func testIntensityClampsAndDurationBuckets() {
        XCTAssertEqual(SurgeRecord(kind: .hotFlash, startedAt: .now, durationSec: 1, intensity: 9, source: .app).intensity, 5)
        XCTAssertEqual(DurationBucket(seconds: 30), .underOne)
        XCTAssertEqual(DurationBucket(seconds: 299), .oneToFive)
        XCTAssertEqual(DurationBucket(seconds: 900), .overFifteen)
    }
}

final class GrowthRuleTests: XCTestCase {
    private let f = Fixture()
    private let engine = InsightEngine()

    func testCyclePhase() {
        var surges: [SurgeRecord] = []
        var checkIns: [CheckInRecord] = []
        let starts = [f.day(-60), f.day(-32), f.day(-4)]
        let before = Set(starts.flatMap { s in (1...3).map { s.adding(days: -$0) } })
        for o in -70...0 {
            let d = f.day(o)
            checkIns.append(CheckInRecord(day: d, scores: [.sleep: 6]))
            let n = before.contains(d) ? 3 : 1
            surges += (0..<n).map { k in f.surge(o, hour: 10 + k) }
        }
        let i = engine.cyclePhase(InsightInput(surges: surges, checkIns: checkIns, cycleStarts: starts), today: f.today)
        guard case .cyclePhase(let cycles, let b, let o)? = i?.kind else { return XCTFail("expected insight") }
        XCTAssertEqual(cycles, 3)
        XCTAssertEqual(b, 3.0)
        XCTAssertEqual(o, 1.0)
    }

    func testCyclePhaseNeedsTwoCycles() {
        let surges = (-40...0).map { f.surge($0, hour: 10) }
        XCTAssertNil(engine.cyclePhase(InsightInput(surges: surges, cycleStarts: [f.day(-10)]), today: f.today))
    }

    func testTonightHeadsUp() {
        var surges: [SurgeRecord] = []
        var checkIns: [CheckInRecord] = []
        for o in -14 ... -1 {
            let a = o % 3 == 0
            checkIns.append(CheckInRecord(day: f.day(o), scores: [:], alcohol: a))
            if a { surges.append(f.surge(o + 1, hour: 3, kind: .nightSweat)) }
        }
        var input = InsightInput(surges: surges, checkIns: checkIns)
        XCTAssertNil(engine.tonightHeadsUp(input, today: f.today), "no alcohol today")
        input.checkIns.append(CheckInRecord(day: f.today, scores: [:], alcohol: true))
        let h = engine.tonightHeadsUp(input, today: f.today)
        XCTAssertEqual(h?.alcoholEvenings, 4)
        XCTAssertEqual(h?.sweatNights, 4)
    }

    func testSampleSeriesProducesInsightsAndIsDeterministic() {
        let a = SampleSeries.twoWeeks(endingOn: f.today), b = SampleSeries.twoWeeks(endingOn: f.today)
        XCTAssertEqual(a.surges.map(\.startedAt), b.surges.map(\.startedAt))
        XCTAssertFalse(engine.compute(a, today: f.today).isEmpty)
    }
}
