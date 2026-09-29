import Foundation

/// Read-only projection of app state for widgets and the Watch. The app is the only writer.
/// Holds counts and levels only: no notes, medication names or free text.
public struct MenoSnapshot: Codable, Hashable, Sendable {
    public struct Cell: Codable, Hashable, Sendable {
        public var day: DayKey
        public var count: Int
        public var level: Int
        public init(day: DayKey, count: Int, level: Int) {
            self.day = day
            self.count = count
            self.level = level
        }
    }

    public struct ActiveSurge: Codable, Hashable, Sendable {
        public var id: UUID
        public var kind: SurgeKind
        public var startedAt: Date
        public init(id: UUID, kind: SurgeKind, startedAt: Date) {
            self.id = id
            self.kind = kind
            self.startedAt = startedAt
        }
    }

    public struct Appointment: Codable, Hashable, Sendable {
        public var date: Date
        public var readiness: Double
        public init(date: Date, readiness: Double) {
            self.date = date
            self.readiness = readiness
        }
    }

    public var todayCount: Int
    public var last7: [Cell]
    public var appointment: Appointment?
    public var activeSurge: ActiveSurge?
    public var isPro: Bool
    public var updatedAt: Date

    public init(todayCount: Int, last7: [Cell], appointment: Appointment?, activeSurge: ActiveSurge?, isPro: Bool, updatedAt: Date) {
        self.todayCount = todayCount
        self.last7 = last7
        self.appointment = appointment
        self.activeSurge = activeSurge
        self.isPro = isPro
        self.updatedAt = updatedAt
    }

    public static let empty = MenoSnapshot(todayCount: 0, last7: [], appointment: nil, activeSurge: nil, isPro: false, updatedAt: .distantPast)
}

/// App Group identifiers shared by the app, widgets and intents.
public enum MenoShared {
    public static let appGroupID = "group.app.gwlabs.menomap"
    public static let snapshotKey = "meno.snapshot.v1"
    public static let activeSurgeKey = "meno.activeSurge.v1"
    public static let pendingEventsKey = "meno.pendingEvents.v1"
}

/// A surge captured outside the main app process (Watch, or a widget/control fallback), queued
/// until the app imports it. The app de-duplicates by `id`.
public struct PendingSurge: Codable, Hashable, Sendable {
    public var record: SurgeRecord
    public init(record: SurgeRecord) { self.record = record }
}

/// Messages between Watch and phone over WatchConnectivity (`transferUserInfo`).
public enum WatchMessage: Codable, Hashable, Sendable {
    /// A finished surge logged on the Watch.
    case surge(SurgeRecord)
    /// Phone → Watch: fresh snapshot for complications and the Watch home screen.
    case snapshot(MenoSnapshot)

    public static let userInfoKey = "meno.watch.message"

    public func userInfo() -> [String: Any] {
        guard let data = try? JSONEncoder().encode(self) else { return [:] }
        return [Self.userInfoKey: data]
    }

    public init?(userInfo: [String: Any]) {
        guard let data = userInfo[Self.userInfoKey] as? Data,
              let msg = try? JSONDecoder().decode(WatchMessage.self, from: data) else { return nil }
        self = msg
    }
}

/// Mapping between MenoMap values and Apple Health's symptom severity (HKCategoryValueSeverity raw values),
/// kept here without importing HealthKit so it's unit-testable on the Mac.
public enum HealthSeverity: Int, Sendable {
    case unspecified = 0, notPresent = 1, mild = 2, moderate = 3, severe = 4

    /// Intensity 1–2 → mild, 3–4 → moderate, 5 → severe; unrated → unspecified.
    public init(intensity: Int?) {
        switch intensity {
        case .none: self = .unspecified
        case .some(let v) where v <= 2: self = .mild
        case .some(let v) where v <= 4: self = .moderate
        default: self = .severe
        }
    }

    /// Back to MenoMap intensity when importing: mild 2, moderate 3, severe 5, otherwise unrated.
    public var intensity: Int? {
        switch self {
        case .mild: 2
        case .moderate: 3
        case .severe: 5
        case .unspecified, .notPresent: nil
        }
    }
}

/// Region-dependent details: paper size and the emergency number shown in safety copy.
public enum RegionInfo {
    public enum PaperSize: String, Codable, CaseIterable, Sendable {
        case letter, a4

        /// Points at 72 dpi.
        public var size: (width: Double, height: Double) {
            switch self {
            case .letter: (612, 792)
            case .a4: (595.28, 841.89)
            }
        }
    }

    /// Letter in the US, Canada, Mexico, the Philippines and Chile; A4 elsewhere.
    public static func paperSize(regionCode: String?) -> PaperSize {
        guard let r = regionCode?.uppercased() else { return .a4 }
        return ["US", "CA", "MX", "PH", "CL", "PR"].contains(r) ? .letter : .a4
    }

    /// Ambulance / general emergency numbers, verified per country before release (see Docs/MARKETS.md).
    /// Unknown regions return nil and the copy falls back to "your local emergency number".
    public static let emergencyNumbers: [String: String] = [
        "US": "911", "CA": "911", "MX": "911", "PR": "911",
        "GB": "999", "IE": "112",
        "AU": "000", "NZ": "111",
        "JP": "119", "KR": "119", "TW": "119",
        "IL": "101", "SA": "997", "AE": "998",
        "IN": "112", "ZA": "10177", "BR": "192", "HK": "999", "SG": "995",
        // EU/EEA single emergency number
        "AT": "112", "BE": "112", "BG": "112", "HR": "112", "CY": "112", "CZ": "112", "DK": "112", "EE": "112",
        "FI": "112", "FR": "112", "DE": "112", "GR": "112", "HU": "112", "IT": "112", "LV": "112", "LT": "112",
        "LU": "112", "MT": "112", "NL": "112", "PL": "112", "PT": "112", "RO": "112", "SK": "112", "SI": "112",
        "ES": "112", "SE": "112", "NO": "112", "IS": "112", "CH": "112", "LI": "112", "UA": "112", "TR": "112",
    ]

    public static func emergencyNumber(regionCode: String?) -> String? {
        guard let r = regionCode?.uppercased() else { return nil }
        return emergencyNumbers[r]
    }
}
