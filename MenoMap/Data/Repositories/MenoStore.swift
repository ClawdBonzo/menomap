import Foundation
import SwiftData
import MenoCore

protocol SurgeStoreing {
    func insertSurge(_ record: SurgeRecord) -> SurgeEvent
    func surge(id: UUID) -> SurgeEvent?
    func surgeRecords(in window: DayWindow?) -> [SurgeRecord]
    func deleteSurge(_ event: SurgeEvent)
}

protocol CheckInStoreing {
    func checkIn(for day: DayKey) -> DailyCheckIn?
    func upsertCheckIn(_ record: CheckInRecord) -> DailyCheckIn
    func checkInRecords(in window: DayWindow?) -> [CheckInRecord]
}

/// SwiftData-backed repository. Main-actor only; views observe through @Query or `revision`.
@MainActor
@Observable
final class MenoStore: SurgeStoreing, CheckInStoreing {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }
    /// Bumped on every write so computed screens (insights, stats) refresh.
    private(set) var revision = 0

    init(container: ModelContainer) {
        self.container = container
    }

    func save() {
        do { try context.save() } catch { MenoLog.store.error("save failed: \(error.localizedDescription, privacy: .public)") }
        revision += 1
    }

    // MARK: Profile

    func profile() -> UserProfile {
        if let p = try? context.fetch(FetchDescriptor<UserProfile>()).first { return p }
        let p = UserProfile()
        context.insert(p)
        save()
        return p
    }

    // MARK: Surges

    @discardableResult
    func insertSurge(_ record: SurgeRecord) -> SurgeEvent {
        if let existing = surge(id: record.id) { return existing }
        let e = SurgeEvent(record: record)
        context.insert(e)
        save()
        return e
    }

    func surge(id: UUID) -> SurgeEvent? {
        var d = FetchDescriptor<SurgeEvent>(predicate: #Predicate { $0.id == id })
        d.fetchLimit = 1
        return try? context.fetch(d).first
    }

    func surge(hkSampleUUID: UUID) -> SurgeEvent? {
        var d = FetchDescriptor<SurgeEvent>(predicate: #Predicate { $0.hkSampleUUID == hkSampleUUID })
        d.fetchLimit = 1
        return try? context.fetch(d).first
    }

    func surgeEvents(in window: DayWindow? = nil) -> [SurgeEvent] {
        var d = FetchDescriptor<SurgeEvent>(sortBy: [SortDescriptor(\.startedAt, order: .reverse)])
        if let window {
            let from = window.start.startDate(), to = window.end.endDate()
            d.predicate = #Predicate { $0.startedAt >= from && $0.startedAt < to }
        }
        return (try? context.fetch(d)) ?? []
    }

    func surgeRecords(in window: DayWindow? = nil) -> [SurgeRecord] {
        surgeEvents(in: window).map(\.record)
    }

    func unratedSurges() -> [SurgeEvent] {
        let d = FetchDescriptor<SurgeEvent>(predicate: #Predicate { $0.intensity == nil },
                                            sortBy: [SortDescriptor(\.startedAt, order: .reverse)])
        return ((try? context.fetch(d)) ?? []).filter { $0.sourceRaw != SurgeSource.healthImport.rawValue }
    }

    func deleteSurge(_ event: SurgeEvent) {
        context.delete(event)
        save()
    }

    // MARK: Check-ins

    func checkIn(for day: DayKey) -> DailyCheckIn? {
        let key = day.description
        var d = FetchDescriptor<DailyCheckIn>(predicate: #Predicate { $0.dayKey == key })
        d.fetchLimit = 1
        return try? context.fetch(d).first
    }

    @discardableResult
    func upsertCheckIn(_ record: CheckInRecord) -> DailyCheckIn {
        let c = checkIn(for: record.day) ?? {
            let n = DailyCheckIn(day: record.day)
            context.insert(n)
            return n
        }()
        // Merge: metrics not in this check-in keep their earlier values (turning a metric off never deletes history).
        var merged = c.scoresRaw
        for (m, v) in record.scores { merged[m.rawValue] = v }
        c.scoresRaw = merged
        if let a = record.alcohol { c.alcohol = a }
        if let lc = record.lateCaffeine { c.lateCaffeine = lc }
        if let n = record.note { c.note = n.isEmpty ? nil : n }
        c.updatedAt = .now
        save()
        return c
    }

    func checkInRecords(in window: DayWindow? = nil) -> [CheckInRecord] {
        let all = (try? context.fetch(FetchDescriptor<DailyCheckIn>(sortBy: [SortDescriptor(\.dayKey, order: .reverse)]))) ?? []
        let records = all.map(\.record)
        guard let window else { return records }
        return records.filter { window.contains($0.day) }
    }

    // MARK: Medications

    func medications(includeEnded: Bool = true) -> [Medication] {
        let all = (try? context.fetch(FetchDescriptor<Medication>(sortBy: [SortDescriptor(\.startDate, order: .reverse)]))) ?? []
        return includeEnded ? all : all.filter { $0.endDate == nil || $0.endDate! > .now }
    }

    func doses() -> [MedicationDose] {
        (try? context.fetch(FetchDescriptor<MedicationDose>(sortBy: [SortDescriptor(\.takenAt, order: .reverse)]))) ?? []
    }

    func logDose(medicationID: UUID, at: Date = .now, skipped: Bool) {
        context.insert(MedicationDose(medicationID: medicationID, takenAt: at, skipped: skipped))
        save()
    }

    // MARK: Cycle

    func cycleNotes() -> [CycleNote] {
        (try? context.fetch(FetchDescriptor<CycleNote>(sortBy: [SortDescriptor(\.start, order: .reverse)]))) ?? []
    }

    // MARK: Appointments

    func appointments() -> [Appointment] {
        (try? context.fetch(FetchDescriptor<Appointment>(sortBy: [SortDescriptor(\.date)]))) ?? []
    }

    /// The next appointment from today on (an appointment stays "next" through its own day).
    func nextAppointment(now: Date = .now) -> Appointment? {
        let startOfToday = DayKey.today(now: now).startDate()
        return appointments().first { $0.date >= startOfToday }
    }

    // MARK: Experiments

    func experiments() -> [Experiment] {
        (try? context.fetch(FetchDescriptor<Experiment>(sortBy: [SortDescriptor(\.startDayKey, order: .reverse)]))) ?? []
    }

    func activeExperiment(today: DayKey = .today()) -> Experiment? {
        experiments().first { !$0.abandoned && !$0.record.isFinished(today: today) }
    }

    // MARK: Health cache

    func healthNights() -> [HealthNight] {
        (try? context.fetch(FetchDescriptor<HealthNight>())) ?? []
    }

    func healthNight(for morning: DayKey) -> HealthNight {
        let key = morning.description
        var d = FetchDescriptor<HealthNight>(predicate: #Predicate { $0.morningKey == key })
        d.fetchLimit = 1
        if let n = try? context.fetch(d).first { return n }
        let n = HealthNight(morning: morning)
        context.insert(n)
        return n
    }

    func healthSymptoms() -> [HealthSymptom] {
        (try? context.fetch(FetchDescriptor<HealthSymptom>(sortBy: [SortDescriptor(\.date, order: .reverse)]))) ?? []
    }

    func hasHealthSymptom(sampleUUID: UUID) -> Bool {
        var d = FetchDescriptor<HealthSymptom>(predicate: #Predicate { $0.hkSampleUUID == sampleUUID })
        d.fetchLimit = 1
        return ((try? context.fetchCount(d)) ?? 0) > 0
    }

    // MARK: Insight input

    func insightInput() -> InsightInput {
        let nights = healthNights()
        return InsightInput(
            surges: surgeRecords(),
            checkIns: checkInRecords(),
            medications: medications().map(\.record),
            doses: doses().map(\.record),
            sleep: nights.compactMap { n in
                guard let m = n.minutesAsleep, let d = DayKey(string: n.morningKey) else { return nil }
                return SleepNight(morning: d, minutesAsleep: m)
            },
            wristTemp: nights.compactMap { n in
                guard let t = n.wristTempDelta, let d = DayKey(string: n.morningKey) else { return nil }
                return WristTempNight(morning: d, deviationCelsius: t)
            },
            experiments: experiments().filter { !$0.abandoned }.map(\.record)
        )
    }

    /// Days with a surge or a check-in.
    func loggedDays(in window: DayWindow) -> Set<DayKey> {
        Set(surgeRecords(in: window).map(\.day)).union(checkInRecords(in: window).map(\.day))
    }

    // MARK: Delete all

    /// Deletes every record on this device (two-step confirm lives in the UI). Apple Health data is untouched.
    func deleteAll() {
        for model in MenoSchema.models {
            try? context.delete(model: model)
        }
        save()
    }
}
