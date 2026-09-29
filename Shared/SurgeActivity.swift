import ActivityKit
import AppIntents
import Foundation
import MenoCore

/// Live Activity for a running surge (adapted from CalmAnchor's PanicBreathingAttributes).
/// Lock Screen + Dynamic Island show a count-up timer, the kind, and End / Night sweat buttons.
struct SurgeActivityAttributes: ActivityAttributes {
    let surgeID: UUID
    let startedAt: Date

    struct ContentState: Codable, Hashable {
        var kind: SurgeKind
        /// Night styling: dim, red-shifted.
        var isNight: Bool
    }
}

// MARK: - Intent bridge

/// Implemented by the app (SurgeController). Intents run in the app process
/// (LiveActivityIntent), so the handler is present; the fallback path only covers edge cases.
@MainActor
protocol SurgeIntentHandling: AnyObject {
    func startSurgeFromIntent(kind: SurgeKind, source: SurgeSource) async
    func endSurgeFromIntent() async
    func toggleSurgeKindFromIntent() async
}

@MainActor
enum SurgeIntentBridge {
    static weak var handler: SurgeIntentHandling?
}

// MARK: - Intents

enum SurgeKindAppEnum: String, AppEnum {
    case hotFlash, nightSweat

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Surge"
    static let caseDisplayRepresentations: [SurgeKindAppEnum: DisplayRepresentation] = [
        .hotFlash: "Hot flash",
        .nightSweat: "Night sweat",
    ]

    var kind: SurgeKind { self == .hotFlash ? .hotFlash : .nightSweat }
}

/// Starts a surge without opening the app: Control Center, Lock Screen control, Action Button, Siri, widget.
struct StartSurgeIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Start a surge"
    static let description = IntentDescription("Starts timing a hot flash or night sweat in MenoMap.")
    static let openAppWhenRun = false

    @Parameter(title: "Kind", default: .hotFlash)
    var kind: SurgeKindAppEnum

    init() {}
    init(kind: SurgeKindAppEnum) { self.kind = kind }

    @MainActor
    func perform() async throws -> some IntentResult {
        if let handler = SurgeIntentBridge.handler {
            await handler.startSurgeFromIntent(kind: kind.kind, source: .intent)
        } else if ActiveSurgeStore.read() == nil {
            ActiveSurgeStore.write(.init(id: UUID(), kind: kind.kind, startedAt: .now))
        }
        return .result()
    }
}

/// Ends the running surge (Live Activity button, Siri). It's saved unrated; the app asks for a rating later.
struct EndSurgeIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "End surge"
    static let description = IntentDescription("Stops the timer and saves the surge in MenoMap.")
    static let openAppWhenRun = false

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        if let handler = SurgeIntentBridge.handler {
            await handler.endSurgeFromIntent()
        } else if let active = ActiveSurgeStore.read() {
            let secs = max(Int(Date.now.timeIntervalSince(active.startedAt)), 1)
            PendingSurgeQueue.append(SurgeRecord(id: active.id, kind: active.kind, startedAt: active.startedAt,
                                                 durationSec: min(secs, 3600), intensity: nil, source: .liveActivity))
            ActiveSurgeStore.clear()
        }
        return .result()
    }
}

/// Switches the running surge between hot flash and night sweat.
struct ToggleSurgeKindIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Switch surge type"
    static let isDiscoverable = false
    static let openAppWhenRun = false

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        await SurgeIntentBridge.handler?.toggleSurgeKindFromIntent()
        return .result()
    }
}
