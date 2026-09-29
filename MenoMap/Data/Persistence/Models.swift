import Foundation
import SwiftData
import MenoCore

// SwiftData models. Every record has id, createdAt, updatedAt.
// Never persisted: inferred diagnosis, a "menopause score", predicted periods, or chat transcripts.

enum VoiceStyle: String, Codable, CaseIterable {
    case wry, straight
}

@Model
final class UserProfile {
    var id: UUID = UUID()
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    var firstName: String?
    var stageRaw: String?
    /// Where the stage came from: "user" or "health".
    var stageSource: String?
    var trackedMetricsRaw: [String] = TrackedMetric.defaultEnabled.map(\.rawValue)
    var whyHereRaw: [String] = []
    var reminderHour: Int?
    var reminderMinute: Int = 0
    var healthKitOn: Bool = false
    var voiceRaw: String?
    var onboardingDone: Bool = false
    var cycleTrackingOn: Bool = false
    var noLongerHasPeriods: Bool = false
    var medicationsConfirmedNone: Bool = false
    var showMedNamesOnShare: Bool = false
    var showQROnShare: Bool = true
    var paperSizeRaw: String?
    /// ISO date of the last free "Pro reveal" on the Stats screen (one per week).
    var lastFreeRevealDay: String?
    var checkInCount: Int = 0
    var hasSeenSurgeSetup: Bool = false
    var healthImportDone: Bool = false
    // Night Watch (bedtime → morning Lock Screen button)
    var nightWatchOn: Bool = false
    var bedtimeHour: Int = 22
    var bedtimeMinute: Int = 30
    var wakeHour: Int = 6
    var wakeMinute: Int = 30
    /// Best calm stretch the user has seen, so a new record can trigger a (positive-moment) review prompt.
    var bestCalmStretch: Int = 0
    /// Weekly Wrap card dismissed for this week (Gregorian "YYYY-MM-DD" of the week's Sunday).
    var weeklyWrapDismissed: String?
    var weeklyWrapNotify: Bool = false

    init() {}

    var stage: MenopauseStage? {
        get { stageRaw.flatMap(MenopauseStage.init(rawValue:)) }
        set { stageRaw = newValue?.rawValue; updatedAt = .now }
    }

    var trackedMetrics: [TrackedMetric] {
        get { trackedMetricsRaw.compactMap(TrackedMetric.init(rawValue:)) }
        set { trackedMetricsRaw = newValue.map(\.rawValue); updatedAt = .now }
    }

    var voice: VoiceStyle {
        get { voiceRaw.flatMap(VoiceStyle.init(rawValue:)) ?? Locale.current.defaultVoice }
        set { voiceRaw = newValue.rawValue; updatedAt = .now }
    }

    var paperSize: RegionInfo.PaperSize {
        get { paperSizeRaw.flatMap(RegionInfo.PaperSize.init(rawValue:)) ?? RegionInfo.paperSize(regionCode: Locale.current.region?.identifier) }
        set { paperSizeRaw = newValue.rawValue }
    }

    /// Bleeding needs the "should be checked" banner.
    var bleedingNeedsCheck: Bool {
        noLongerHasPeriods || (stage?.bleedingNeedsCheck ?? false)
    }
}

extension Locale {
    /// Wry where menopause humor is mainstream; Straight elsewhere (Docs/SPEC_ADDITIONS §6).
    var defaultVoice: VoiceStyle {
        let straight: Set<String> = ["ja", "ko", "zh", "ar", "he", "th", "vi", "id", "ms", "hi", "tr"]
        return straight.contains(language.languageCode?.identifier ?? "en") ? .straight : .wry
    }
}

@Model
final class SurgeEvent {
    var id: UUID = UUID()
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    var kindRaw: String = SurgeKind.hotFlash.rawValue
    var startedAt: Date = Date.now
    var durationSec: Int = 0
    var intensity: Int?
    var tagsRaw: [String] = []
    var sourceRaw: String = SurgeSource.app.rawValue
    /// The Apple Health sample MenoMap wrote (or imported) for this event.
    var hkSampleUUID: UUID?

    init(record: SurgeRecord) {
        id = record.id
        apply(record)
    }

    func apply(_ r: SurgeRecord) {
        kindRaw = r.kind.rawValue
        startedAt = r.startedAt
        durationSec = r.durationSec
        intensity = r.intensity
        tagsRaw = r.tags.map(\.rawValue)
        sourceRaw = r.source.rawValue
        updatedAt = .now
    }

    var record: SurgeRecord {
        SurgeRecord(id: id, kind: SurgeKind(rawValue: kindRaw) ?? .hotFlash, startedAt: startedAt, durationSec: durationSec,
                    intensity: intensity, tags: tagsRaw.compactMap(SurgeTag.init(rawValue:)),
                    source: SurgeSource(rawValue: sourceRaw) ?? .app)
    }

    var kind: SurgeKind { SurgeKind(rawValue: kindRaw) ?? .hotFlash }
}

@Model
final class DailyCheckIn {
    var id: UUID = UUID()
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    /// "YYYY-MM-DD" Gregorian day key.
    var dayKey: String = DayKey.today().description
    var scoresRaw: [String: Int] = [:]
    var alcohol: Bool?
    var lateCaffeine: Bool?
    var note: String?

    init(day: DayKey) {
        dayKey = day.description
    }

    var day: DayKey { DayKey(string: dayKey) ?? .today() }

    var record: CheckInRecord {
        var scores: [TrackedMetric: Int] = [:]
        for (k, v) in scoresRaw { if let m = TrackedMetric(rawValue: k) { scores[m] = v } }
        return CheckInRecord(id: id, day: day, scores: scores, alcohol: alcohol, lateCaffeine: lateCaffeine, note: note)
    }
}

@Model
final class CycleNote {
    var id: UUID = UUID()
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    var start: Date = Date.now
    var end: Date?
    var flowRaw: String = Flow.light.rawValue
    var note: String?
    /// True when logged while the profile said post-menopause / no periods → banner fired.
    var isPostMenopauseFlag: Bool = false
    var unusualFlag: Bool = false
    var hkSampleUUID: UUID?

    init(start: Date, flow: Flow) {
        self.start = start
        flowRaw = flow.rawValue
    }

    var flow: Flow { Flow(rawValue: flowRaw) ?? .light }
}

@Model
final class Medication {
    var id: UUID = UUID()
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    var name: String = ""
    var doseText: String = ""
    var route: String = ""
    var scheduleText: String = ""
    var categoryRaw: String = MedicationCategory.other.rawValue
    var startDate: Date = Date.now
    var endDate: Date?
    var notes: String = ""
    var reminderOn: Bool = false
    var reminderHour: Int = 9
    var reminderMinute: Int = 0
    /// "daily", "days" (specific weekdays, e.g. a twice-weekly patch) or "asNeeded".
    var scheduleKindRaw: String = MedicationSchedule.daily.rawValue
    /// Gregorian weekdays 1 (Sun)…7 (Sat) when `scheduleKindRaw == "days"`.
    var weekdays: [Int] = []

    init(name: String, category: MedicationCategory, startDate: Date) {
        self.name = name
        categoryRaw = category.rawValue
        self.startDate = startDate
    }

    var category: MedicationCategory { MedicationCategory(rawValue: categoryRaw) ?? .other }
    var schedule: MedicationSchedule {
        get { MedicationSchedule(rawValue: scheduleKindRaw) ?? .daily }
        set { scheduleKindRaw = newValue.rawValue }
    }

    var record: MedicationRecord {
        MedicationRecord(id: id, name: name, category: category, startDate: startDate, endDate: endDate)
    }
}

@Model
final class MedicationDose {
    var id: UUID = UUID()
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    var medicationID: UUID = UUID()
    var takenAt: Date = Date.now
    var skipped: Bool = false

    init(medicationID: UUID, takenAt: Date, skipped: Bool) {
        self.medicationID = medicationID
        self.takenAt = takenAt
        self.skipped = skipped
    }

    var record: DoseRecord { DoseRecord(medicationID: medicationID, at: takenAt, skipped: skipped) }
}

enum MedicationSchedule: String, Codable, CaseIterable {
    case daily, days, asNeeded
}

enum VisitTopic: String, Codable, CaseIterable {
    case hotFlashes, nightSweats, sleep, mood, bleeding, currentTreatment, vaginalUrinary, weight, other
}

@Model
final class Appointment {
    var id: UUID = UUID()
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    var date: Date = Date.now
    var title: String = ""
    var clinicianName: String?
    var topicsRaw: [String] = []
    /// Question keys the user picked (see VisitQuestions) plus any custom questions, prefixed "custom:".
    var questions: [String] = []
    /// Language code for the PDF; nil = app language.
    var pdfLanguage: String?
    /// Follow-up answer the day after: "good", "mixed", "missed".
    var outcome: String?

    init(date: Date, title: String = "") {
        self.date = date
        self.title = title
    }

    var topics: [VisitTopic] {
        get { topicsRaw.compactMap(VisitTopic.init(rawValue:)) }
        set { topicsRaw = newValue.map(\.rawValue); updatedAt = .now }
    }
}

@Model
final class Experiment {
    var id: UUID = UUID()
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    var kindRaw: String = ExperimentKind.custom.rawValue
    var customTitle: String?
    var startDayKey: String = DayKey.today().description
    var lengthDays: Int = 14
    var abandoned: Bool = false

    init(kind: ExperimentKind, startDay: DayKey, customTitle: String? = nil) {
        kindRaw = kind.rawValue
        startDayKey = startDay.description
        self.customTitle = customTitle
    }

    var record: ExperimentRecord {
        ExperimentRecord(id: id, kind: ExperimentKind(rawValue: kindRaw) ?? .custom, customTitle: customTitle,
                         startDay: DayKey(string: startDayKey) ?? .today(), lengthDays: lengthDays)
    }
}

/// Other symptoms found in Apple Health (palpitations, vaginal dryness…). Shown in the PDF, never inferred.
@Model
final class HealthSymptom {
    var id: UUID = UUID()
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    var typeRaw: String = ""
    var date: Date = Date.now
    var severityRaw: Int = 0
    var hkSampleUUID: UUID = UUID()

    init(typeRaw: String, date: Date, severityRaw: Int, hkSampleUUID: UUID) {
        self.typeRaw = typeRaw
        self.date = date
        self.severityRaw = severityRaw
        self.hkSampleUUID = hkSampleUUID
    }
}

enum HealthSymptomType {
    /// Marker row for a period start read from Apple Health (menstrual flow with the cycle-start flag).
    static let cycleStart = "meno.cycleStart"
}

/// Cached nightly values from Apple Health, keyed by the morning.
@Model
final class HealthNight {
    var id: UUID = UUID()
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    var morningKey: String = ""
    var minutesAsleep: Int?
    var wristTempDelta: Double?

    init(morning: DayKey) {
        morningKey = morning.description
    }
}

enum MenoSchema {
    static let models: [any PersistentModel.Type] = [
        UserProfile.self, SurgeEvent.self, DailyCheckIn.self, CycleNote.self, Medication.self, MedicationDose.self,
        Appointment.self, Experiment.self, HealthSymptom.self, HealthNight.self,
    ]

    /// Explicit URL in the app's own Application Support. With an App Groups entitlement SwiftData's default
    /// store silently moves into the shared container (WishLock lesson); health data stays in the app sandbox.
    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(models)
        let config: ModelConfiguration
        if inMemory {
            config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        } else {
            let dir = URL.applicationSupportDirectory.appending(path: "MenoMap", directoryHint: .isDirectory)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            config = ModelConfiguration(schema: schema, url: dir.appending(path: "MenoMap.store"),
                                        cloudKitDatabase: .none)
        }
        return try ModelContainer(for: schema, configurations: [config])
    }
}
