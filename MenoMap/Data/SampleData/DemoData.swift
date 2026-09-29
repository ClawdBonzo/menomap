#if DEBUG
import Foundation
import MenoCore

/// Fictional data for simulator runs and screenshots. DEBUG only; never in Release builds.
///
/// Launch arguments:
///   -MMDemo            load ~60 days of demo data (replaces the store)
///   -MMSkipOnboarding  mark onboarding done
///   -MMInMemory        use an in-memory store
///   -MMPro / -MMFree   force the entitlement
///   -MMTab week|visit|you   open a tab
///   -MMSheet surge|night|checkin|paywall|setup   present a sheet at launch
@MainActor
enum DemoData {
    static func applyLaunchArguments(to container: AppContainer) {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-MMDemo") { load(into: container) }
        if args.contains("-MMSkipOnboarding") || args.contains("-MMDemo") {
            let p = container.store.profile()
            p.onboardingDone = true
            p.hasSeenSurgeSetup = true
            container.store.save()
        }
        if args.contains("-MMArmNightWatch") {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1))
                container.nightWatch.arm()
            }
        }
        if let i = args.firstIndex(of: "-MMSheet"), i + 1 < args.count {
            let sheet: AppSheet? = switch args[i + 1] {
            case "surge": .surge(.hotFlash)
            case "night": .surge(.nightSweat)
            case "checkin": .checkIn
            case "paywall": .paywall(.pdf)
            case "setup": .surgeSetup
            default: nil
            }
            if let sheet {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(800))
                    container.router.present(sheet)
                }
            }
        }
        if let i = args.firstIndex(of: "-MMTab"), i + 1 < args.count {
            switch args[i + 1] {
            case "week": container.router.tab = .week
            case "visit": container.router.tab = .visit
            case "you": container.router.tab = .you
            default: break
            }
        }
    }

    static func load(into container: AppContainer) {
        let store = container.store
        store.deleteAll()
        container.surges.cancel()
        var rng = SeededGenerator(seed: 42)
        let cal = Calendar.menoGregorian
        let today = DayKey.today()

        let p = store.profile()
        p.firstName = "Dana"
        p.stage = .perimenopause
        p.stageSource = "user"
        p.onboardingDone = true
        p.hasSeenSurgeSetup = true
        p.trackedMetrics = [.sleep, .hotFlashes, .mood, .energy, .brainFog]

        let medStart = cal.date(from: DateComponents(year: today.adding(days: -24).year, month: today.adding(days: -24).month,
                                                     day: today.adding(days: -24).day, hour: 9))!
        let med = Medication(name: "Estradiol gel", category: .estrogen, startDate: medStart)
        med.doseText = "1 pump"
        med.route = "Skin"
        med.scheduleText = "Every morning"
        store.context.insert(med)
        let prog = Medication(name: "Micronized progesterone", category: .progestogen, startDate: medStart)
        prog.doseText = "100 mg"
        prog.route = "By mouth"
        prog.scheduleText = "At bedtime"
        store.context.insert(prog)

        for offset in -59...0 {
            let day = today.adding(days: offset)
            let afterMed = offset > -24
            let weekend = [1, 7].contains(day.weekday())
            let alcohol = weekend ? Bool.random(using: &rng) || Int.random(in: 0..<3, using: &rng) == 0 : Int.random(in: 0..<6, using: &rng) == 0
            let base = afterMed ? 1 : 3
            var count = base + Int.random(in: 0...2, using: &rng) + (alcohol ? 1 : 0)
            if offset == 0 { count = 2 }
            var nightCount = 0
            for i in 0..<count {
                let night = i == 0 || (alcohol && i == 1) || Int.random(in: 0..<4, using: &rng) == 0
                let hour = night ? [1, 2, 3, 3, 3, 4, 23][Int.random(in: 0..<7, using: &rng)] : [10, 13, 15, 16, 19][Int.random(in: 0..<5, using: &rng)]
                if offset == 0 && hour > 12 { continue }
                let minute = hour == 3 ? Int.random(in: 5...20, using: &rng) : Int.random(in: 0...59, using: &rng)
                var comps = DateComponents(year: day.year, month: day.month, day: day.day, hour: hour, minute: minute)
                if hour == 23 { comps.day = day.day } // evening of this day
                guard let start = cal.date(from: comps), start < .now else { continue }
                let intensity = max(1, min(5, (afterMed ? 2 : 4) + Int.random(in: -1...1, using: &rng)))
                var tags: [SurgeTag] = []
                if alcohol && night { tags.append(.alcohol) }
                if Int.random(in: 0..<5, using: &rng) == 0 { tags.append(.stress) }
                if Int.random(in: 0..<8, using: &rng) == 0 { tags.append(.heat) }
                let record = SurgeRecord(kind: night ? .nightSweat : .hotFlash, startedAt: start,
                                         durationSec: Int.random(in: 70...260, using: &rng), intensity: intensity, tags: tags,
                                         source: [.app, .watch, .control, .app][Int.random(in: 0..<4, using: &rng)])
                store.context.insert(SurgeEvent(record: record))
                if night { nightCount += 1 }
            }
            if offset < 0 || true {
                let c = DailyCheckIn(day: day)
                let sleep = max(2, min(9, 8 - nightCount * 2 + Int.random(in: -1...1, using: &rng)))
                c.scoresRaw = [
                    TrackedMetric.sleep.rawValue: sleep,
                    TrackedMetric.hotFlashes.rawValue: min(10, count * 2),
                    TrackedMetric.mood.rawValue: max(3, min(9, sleep + Int.random(in: -1...1, using: &rng))),
                    TrackedMetric.energy.rawValue: max(2, min(9, sleep - 1 + Int.random(in: -1...1, using: &rng))),
                    TrackedMetric.brainFog.rawValue: max(1, min(8, 6 - sleep / 2 + Int.random(in: -1...1, using: &rng))),
                ]
                c.alcohol = alcohol
                c.lateCaffeine = Int.random(in: 0..<5, using: &rng) == 0
                if offset != 0 { store.context.insert(c) }
            }
            let dosed = cal.date(from: DateComponents(year: day.year, month: day.month, day: day.day, hour: 8, minute: 30))!
            if afterMed && dosed < .now {
                store.context.insert(MedicationDose(medicationID: med.id, takenAt: dosed, skipped: Int.random(in: 0..<9, using: &rng) == 0))
            }
            let n = HealthNight(morning: day)
            n.minutesAsleep = 330 + Int.random(in: 0...110, using: &rng) - nightCount * 25
            n.wristTempDelta = Double(nightCount) * 0.18 + Double(Int.random(in: -10...10, using: &rng)) / 100
            store.context.insert(n)
        }

        let exp = Experiment(kind: .noAlcoholAfter7, startDay: today.adding(days: -9))
        store.context.insert(exp)
        let finished = Experiment(kind: .coolerBedroom, startDay: today.adding(days: -44))
        store.context.insert(finished)

        let apptDay = today.adding(days: 9)
        let appt = Appointment(date: cal.date(from: DateComponents(year: apptDay.year, month: apptDay.month, day: apptDay.day, hour: 10, minute: 30))!,
                               title: "Menopause review")
        appt.clinicianName = "Dr. Patel"
        appt.topics = [.hotFlashes, .nightSweats, .sleep, .currentTreatment]
        appt.questions = ["disruptive", "changed", "watchFor", "medsFit"]
        store.context.insert(appt)
        store.save()
    }
}

/// Deterministic RNG so demo screenshots are stable.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed &* 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
#endif
