import ActivityKit
import AppIntents
import Foundation
import MenoCore

/// Night Watch: a quiet Lock Screen Live Activity from bedtime to morning with one big "Night sweat" button,
/// so at 3am logging is a single tap without unlocking. While a night surge runs, the same activity shows the
/// timer and an End button (no second activity).
struct NightWatchAttributes: ActivityAttributes {
    let armedAt: Date
    let wakeAt: Date

    struct ContentState: Codable, Hashable {
        /// Start of the night surge currently being timed, if any.
        var activeSurgeStart: Date?
        /// Night surges logged since Night Watch was armed.
        var tonightCount: Int
    }
}

@MainActor
protocol NightWatchHandling: AnyObject {
    func armNightWatch() async
    func disarmNightWatch() async
}

@MainActor
enum NightWatchBridge {
    static weak var handler: NightWatchHandling?
}

/// Arms Night Watch. Also offered to Shortcuts so "When Sleep Focus turns on → Arm Night Watch" works.
struct ArmNightWatchIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Arm Night Watch"
    static let description = IntentDescription("Puts a one-tap night sweat button on your Lock Screen until morning.")
    static let openAppWhenRun = false

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        await NightWatchBridge.handler?.armNightWatch()
        return .result()
    }
}

struct DisarmNightWatchIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Turn off Night Watch"
    static let openAppWhenRun = false

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        await NightWatchBridge.handler?.disarmNightWatch()
        return .result()
    }
}
