import ActivityKit
import Foundation
import MenoCore

/// Arms and runs Night Watch (Docs/SPEC_ADDITIONS §4 + growth item 1).
///
/// Ways it gets armed (iOS can't start a Live Activity on a timer without a server):
/// - saving the evening check-in (the natural "going to bed" moment)
/// - opening the app within 2 hours of bedtime
/// - the bedtime notification ("Tap to arm Night Watch")
/// - Shortcuts: "When Sleep Focus turns on → Arm Night Watch", the Control, or Siri
@MainActor
@Observable
final class NightWatchController: NightWatchHandling {
    weak var container: AppContainer?

    init() {
        NightWatchBridge.handler = self
    }

    var isArmed: Bool { current != nil }

    private var current: Activity<NightWatchAttributes>? {
        Activity<NightWatchAttributes>.activities.first { $0.activityState == .active || $0.activityState == .stale }
    }

    /// Next wake time after `now`, capped at 8 hours (the Live Activity limit).
    func wakeTime(after now: Date = .now) -> Date {
        let p = container?.store.profile()
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: now)
        comps.hour = p?.wakeHour ?? 6
        comps.minute = p?.wakeMinute ?? 30
        var wake = Calendar.current.date(from: comps) ?? now.addingTimeInterval(8 * 3600)
        if wake <= now { wake = Calendar.current.date(byAdding: .day, value: 1, to: wake) ?? wake }
        return min(wake, now.addingTimeInterval(8 * 3600))
    }

    /// True from 2 hours before bedtime until 3am.
    func isNearBedtime(_ now: Date = .now) -> Bool {
        guard let p = container?.store.profile() else { return false }
        let cal = Calendar.current
        let minutes = cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now)
        let bed = p.bedtimeHour * 60 + p.bedtimeMinute
        let from = (bed - 120 + 1440) % 1440
        let until = 3 * 60
        return from <= until ? (minutes >= from && minutes < until) : (minutes >= from || minutes < until)
    }

    func armNightWatch() async { arm() }
    func disarmNightWatch() async { disarm() }

    func arm() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled, current == nil else { return }
        let now = Date.now
        let attrs = NightWatchAttributes(armedAt: now, wakeAt: wakeTime(after: now))
        let state = NightWatchAttributes.ContentState(activeSurgeStart: container?.surges.active?.startedAt, tonightCount: 0)
        do {
            _ = try Activity.request(attributes: attrs, content: .init(state: state, staleDate: attrs.wakeAt))
            container?.router.toast = String(localized: "Night Watch is on until morning.")
        } catch {
            MenoLog.surge.error("night watch failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func disarm() {
        for a in Activity<NightWatchAttributes>.activities {
            Task { await a.end(nil, dismissalPolicy: .immediate) }
        }
    }

    /// Called by SurgeController whenever a surge starts or ends.
    func update(activeSurgeStart: Date?) {
        guard let a = current else { return }
        let count = container?.store.surgeRecords(in: DayWindow(lastDays: 2, endingOn: .today()))
            .filter { $0.startedAt >= a.attributes.armedAt }.count ?? 0
        let state = NightWatchAttributes.ContentState(activeSurgeStart: activeSurgeStart, tonightCount: count)
        Task { await a.update(.init(state: state, staleDate: a.attributes.wakeAt)) }
    }

    /// Launch / foreground: end last night's watch after wake time; auto-arm near bedtime.
    func reconcile(now: Date = .now) {
        for a in Activity<NightWatchAttributes>.activities where now >= a.attributes.wakeAt {
            Task { await a.end(nil, dismissalPolicy: .immediate) }
        }
        if container?.store.profile().nightWatchOn == true, isNearBedtime(now) { arm() }
    }
}
