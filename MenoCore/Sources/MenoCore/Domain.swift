import Foundation

// Value types shared by the app, widgets, Watch and the insight engine.
// SwiftData @Model classes in the app convert to these; nothing here knows about persistence.

public enum SurgeKind: String, Codable, CaseIterable, Sendable {
    case hotFlash
    case nightSweat
}

public enum SurgeTag: String, Codable, CaseIterable, Sendable {
    case alcohol, heat, stress, exercise, caffeine, spicyFood, unknown
}

/// Where a surge was captured. Used for dedupe and to know when to ask for a rating later.
public enum SurgeSource: String, Codable, CaseIterable, Sendable {
    case app, liveActivity, control, watch, intent, afterTheFact, healthImport
}

/// Buckets for logging a surge after the fact.
public enum DurationBucket: String, Codable, CaseIterable, Sendable {
    case underOne, oneToFive, fiveToFifteen, overFifteen

    /// Representative seconds stored for the bucket (the midpoint, 20 min for the open-ended one).
    public var representativeSeconds: Int {
        switch self {
        case .underOne: 45
        case .oneToFive: 180
        case .fiveToFifteen: 600
        case .overFifteen: 1200
        }
    }

    public init(seconds: Int) {
        switch seconds {
        case ..<60: self = .underOne
        case ..<300: self = .oneToFive
        case ..<900: self = .fiveToFifteen
        default: self = .overFifteen
        }
    }
}

public struct SurgeRecord: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var kind: SurgeKind
    public var startedAt: Date
    public var durationSec: Int
    /// 1…5, nil while unrated (ended from the Lock Screen or Watch without a rating).
    public var intensity: Int?
    public var tags: [SurgeTag]
    public var source: SurgeSource

    public init(id: UUID = UUID(), kind: SurgeKind, startedAt: Date, durationSec: Int,
                intensity: Int?, tags: [SurgeTag] = [], source: SurgeSource) {
        self.id = id
        self.kind = kind
        self.startedAt = startedAt
        self.durationSec = durationSec
        self.intensity = intensity.map { min(max($0, 1), 5) }
        self.tags = tags
        self.source = source
    }

    public var day: DayKey { DayKey(startedAt) }

    /// The morning a surge "belongs" to for sleep pairing: surges before noon count toward that
    /// morning's night; surges from noon on count toward the next morning.
    public func nightKey(calendar: Calendar = .menoGregorian) -> DayKey {
        let d = DayKey(startedAt, calendar: calendar)
        let hour = calendar.component(.hour, from: startedAt)
        return hour < 12 ? d : d.adding(days: 1, calendar: calendar)
    }

    /// Surges between 21:00 and 06:59 count as night surges for stats, regardless of the kind chosen.
    public func isNight(calendar: Calendar = .menoGregorian) -> Bool {
        let hour = calendar.component(.hour, from: startedAt)
        return hour >= 21 || hour < 7
    }
}

public enum TrackedMetric: String, Codable, CaseIterable, Sendable {
    case sleep, hotFlashes, mood, energy, nightSweats, brainFog, stress

    /// Metrics where a higher score is better (for colors and wording only).
    public var higherIsBetter: Bool {
        switch self {
        case .sleep, .mood, .energy: true
        case .hotFlashes, .nightSweats, .brainFog, .stress: false
        }
    }

    public static let defaultEnabled: [TrackedMetric] = [.sleep, .hotFlashes, .mood, .energy]
}

public struct CheckInRecord: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var day: DayKey
    /// 0…10 per metric. Metrics the user later disables keep their history here.
    public var scores: [TrackedMetric: Int]
    /// "Alcohol today?" Asked in the evening check-in; pairs with that night.
    public var alcohol: Bool?
    /// "Caffeine later than usual?"
    public var lateCaffeine: Bool?
    public var note: String?

    public init(id: UUID = UUID(), day: DayKey, scores: [TrackedMetric: Int], alcohol: Bool? = nil,
                lateCaffeine: Bool? = nil, note: String? = nil) {
        self.id = id
        self.day = day
        self.scores = scores.mapValues { min(max($0, 0), 10) }
        self.alcohol = alcohol
        self.lateCaffeine = lateCaffeine
        self.note = note
    }
}

public enum MedicationCategory: String, Codable, CaseIterable, Sendable {
    case estrogen, progestogen, combined, vaginalEstrogen, nonHormonal, supplement, other
}

public struct MedicationRecord: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var category: MedicationCategory
    public var startDate: Date
    public var endDate: Date?

    public init(id: UUID = UUID(), name: String, category: MedicationCategory, startDate: Date, endDate: Date? = nil) {
        self.id = id
        self.name = name
        self.category = category
        self.startDate = startDate
        self.endDate = endDate
    }
}

public struct DoseRecord: Codable, Hashable, Sendable {
    public var medicationID: UUID
    public var at: Date
    public var skipped: Bool

    public init(medicationID: UUID, at: Date, skipped: Bool) {
        self.medicationID = medicationID
        self.at = at
        self.skipped = skipped
    }
}

/// One night of sleep from Apple Health, keyed by the morning it ended.
public struct SleepNight: Codable, Hashable, Sendable {
    public var morning: DayKey
    public var minutesAsleep: Int

    public init(morning: DayKey, minutesAsleep: Int) {
        self.morning = morning
        self.minutesAsleep = minutesAsleep
    }
}

/// Apple Watch sleeping wrist temperature deviation (°C from the personal baseline), keyed by morning.
public struct WristTempNight: Codable, Hashable, Sendable {
    public var morning: DayKey
    public var deviationCelsius: Double

    public init(morning: DayKey, deviationCelsius: Double) {
        self.morning = morning
        self.deviationCelsius = deviationCelsius
    }
}

public enum ExperimentKind: String, Codable, CaseIterable, Sendable {
    case noAlcoholAfter7, noCaffeineAfterNoon, coolerBedroom, eveningBreathing, custom
}

public struct ExperimentRecord: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var kind: ExperimentKind
    public var customTitle: String?
    public var startDay: DayKey
    public var lengthDays: Int

    public init(id: UUID = UUID(), kind: ExperimentKind, customTitle: String? = nil, startDay: DayKey, lengthDays: Int = 14) {
        self.id = id
        self.kind = kind
        self.customTitle = customTitle
        self.startDay = startDay
        self.lengthDays = lengthDays
    }

    public var endDay: DayKey { startDay.adding(days: lengthDays - 1) }
    public var window: DayWindow { DayWindow(start: startDay, end: endDay) }
    /// The same number of days immediately before the experiment.
    public var baseline: DayWindow { window.previous() }

    public func isFinished(today: DayKey) -> Bool { today > endDay }
}

public enum MenopauseStage: String, Codable, CaseIterable, Sendable {
    case perimenopause, menopause, postmenopause, notSure, preferNotToSay

    /// Stages where any new bleeding must show the "should be checked" banner.
    public var bleedingNeedsCheck: Bool { self == .postmenopause || self == .menopause }
}

public enum Flow: String, Codable, CaseIterable, Sendable {
    case spotting, light, medium, heavy
}
