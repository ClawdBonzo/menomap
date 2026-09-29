import ActivityKit
import Foundation
import MenoCore
import UIKit

/// Runs the one active surge: App Group state, Live Activity, haptics. Every entry point (app button,
/// Control, Action Button, Siri, Live Activity buttons) goes through here.
@MainActor
@Observable
final class SurgeController: SurgeIntentHandling {
    weak var container: AppContainer?

    private(set) var active: MenoSnapshot.ActiveSurge?
    /// Surges running longer than this when the app finds them were almost certainly forgotten.
    static let staleAfter: TimeInterval = 60 * 60

    init() {
        active = ActiveSurgeStore.read()
        SurgeIntentBridge.handler = self
    }

    var isRunning: Bool { active != nil }

    func elapsed(now: Date = .now) -> Int {
        guard let a = active else { return 0 }
        return max(Int(now.timeIntervalSince(a.startedAt)), 0)
    }

    /// Starts a surge unless one is already running (then returns the running one).
    @discardableResult
    func start(kind: SurgeKind, source: SurgeSource) -> MenoSnapshot.ActiveSurge {
        if let a = active { return a }
        let a = MenoSnapshot.ActiveSurge(id: UUID(), kind: kind, startedAt: .now)
        active = a
        startSource = source
        ActiveSurgeStore.write(a)
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        startLiveActivity(a)
        container?.refreshSnapshot()
        MenoLog.surge.info("surge started")
        return a
    }

    private var startSource: SurgeSource = .app

    func setKind(_ kind: SurgeKind) {
        guard var a = active, a.kind != kind else { return }
        a.kind = kind
        active = a
        ActiveSurgeStore.write(a)
        updateLiveActivity(a)
    }

    /// Ends the surge and saves it. `durationOverride` comes from the edit field on the end screen.
    @discardableResult
    func finish(intensity: Int?, tags: [SurgeTag], durationOverride: Int? = nil, source: SurgeSource? = nil) -> SurgeEvent? {
        guard let a = active else { return nil }
        let secs = durationOverride ?? min(elapsed(), Int(Self.staleAfter))
        let record = SurgeRecord(id: a.id, kind: a.kind, startedAt: a.startedAt, durationSec: max(secs, 1),
                                 intensity: intensity, tags: tags, source: source ?? startSource)
        clear()
        if let c = container {
            c.router.toast = Copy.savedLine(seconds: record.durationSec, voice: c.store.profile().voice)
        }
        return container?.log(record)
    }

    /// Discard without saving (e.g. started by mistake).
    func cancel() {
        clear()
        container?.refreshSnapshot()
    }

    private func clear() {
        active = nil
        ActiveSurgeStore.clear()
        endLiveActivities()
    }

    /// Called at launch/foreground: adopts a surge started by an extension, closes forgotten ones.
    func reconcile(now: Date = .now) {
        let stored = ActiveSurgeStore.read()
        if active?.id != stored?.id { active = stored }
        guard let a = active else {
            endLiveActivities()
            return
        }
        if now.timeIntervalSince(a.startedAt) > Self.staleAfter {
            // Forgotten timer: save it unrated with unknown duration rather than inventing one.
            let record = SurgeRecord(id: a.id, kind: a.kind, startedAt: a.startedAt, durationSec: 0,
                                     intensity: nil, source: .liveActivity)
            clear()
            container?.log(record)
        } else if Activity<SurgeActivityAttributes>.activities.isEmpty {
            startLiveActivity(a)
        }
    }

    // MARK: SurgeIntentHandling

    func startSurgeFromIntent(kind: SurgeKind, source: SurgeSource) async {
        start(kind: kind, source: source)
    }

    func endSurgeFromIntent() async {
        finish(intensity: nil, tags: [], source: .liveActivity)
    }

    func toggleSurgeKindFromIntent() async {
        guard let a = active else { return }
        setKind(a.kind == .hotFlash ? .nightSweat : .hotFlash)
    }

    // MARK: Live Activity

    private func isNightNow() -> Bool {
        let h = Calendar.current.component(.hour, from: .now)
        return h >= 21 || h < 7
    }

    private func startLiveActivity(_ a: MenoSnapshot.ActiveSurge) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        endLiveActivities()
        let attrs = SurgeActivityAttributes(surgeID: a.id, startedAt: a.startedAt)
        let state = SurgeActivityAttributes.ContentState(kind: a.kind, isNight: isNightNow())
        do {
            _ = try Activity.request(attributes: attrs,
                                     content: .init(state: state, staleDate: a.startedAt.addingTimeInterval(Self.staleAfter)))
        } catch {
            MenoLog.surge.error("live activity failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func updateLiveActivity(_ a: MenoSnapshot.ActiveSurge) {
        let state = SurgeActivityAttributes.ContentState(kind: a.kind, isNight: isNightNow())
        for activity in Activity<SurgeActivityAttributes>.activities {
            Task { await activity.update(.init(state: state, staleDate: a.startedAt.addingTimeInterval(Self.staleAfter))) }
        }
    }

    private func endLiveActivities() {
        for activity in Activity<SurgeActivityAttributes>.activities {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }
}
