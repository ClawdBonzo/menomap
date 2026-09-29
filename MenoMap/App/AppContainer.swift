import Foundation
import SwiftData
import SwiftUI
import WidgetKit
import MenoCore

enum AppTab: Hashable {
    case today, week, visit, you
}

enum PaywallTrigger: String, Identifiable {
    case pdf, pattern, experiment, appointment, checkIns, stats, settings
    var id: String { rawValue }
}

enum AppSheet: Identifiable, Equatable {
    case surge(SurgeKind)
    case afterTheFact
    case checkIn
    case rate(UUID)
    case paywall(PaywallTrigger)
    case surgeSetup
    case medication(UUID?)
    case bleeding
    case samplePreview
    case medications

    var isFullScreen: Bool {
        if case .surge = self { return true }
        return false
    }

    var id: String {
        switch self {
        case .surge(let k): "surge-\(k.rawValue)"
        case .afterTheFact: "after"
        case .checkIn: "checkin"
        case .rate(let id): "rate-\(id)"
        case .paywall(let t): "paywall-\(t.rawValue)"
        case .surgeSetup: "setup"
        case .medication(let id): "med-\(id?.uuidString ?? "new")"
        case .bleeding: "bleeding"
        case .samplePreview: "sample"
        case .medications: "meds"
        }
    }
}

/// Navigation state shared by deep links, intents, notifications and views.
@MainActor
@Observable
final class AppRouter {
    var tab: AppTab = .today
    var sheet: AppSheet?
    /// Short confirmation shown at the bottom of the screen (e.g. after saving a surge).
    var toast: String?

    func present(_ sheet: AppSheet) {
        // Surge always wins: someone mid-flash shouldn't hit a stale sheet.
        if case .surge = sheet { self.sheet = nil }
        self.sheet = sheet
    }

    func handle(url: URL) {
        guard url.scheme == "menomap" else { return }
        switch url.host() {
        case "surge": present(.surge(url.lastPathComponent == "night" ? .nightSweat : .hotFlash))
        case "checkin": present(.checkIn)
        case "visit": tab = .visit; sheet = nil
        case "nightwatch": AppContainer.shared.nightWatch.arm()
        case "meds": present(.medications)
        case "week": tab = .week; sheet = nil
        case "rate":
            if let id = UUID(uuidString: url.lastPathComponent) { present(.rate(id)) }
        default: tab = .today
        }
    }
}

/// Dependency container created once in MenoMapApp. Also reachable from App Intents (`shared`), which run
/// in the app process.
@MainActor
@Observable
final class AppContainer {
    static let shared = AppContainer()

    let store: MenoStore
    let router = AppRouter()
    let subscription: SubscriptionManager
    let surges: SurgeController
    let health: HealthService
    let notifications: NotificationService
    let watch: WatchBridge
    let nightWatch: NightWatchController

    private init() {
        let modelContainer: ModelContainer
        do {
            modelContainer = try MenoSchema.makeContainer(inMemory: ProcessInfo.processInfo.arguments.contains("-MMInMemory"))
        } catch {
            // A broken store must not brick a symptom log: fall back to memory and say so in the log.
            MenoLog.store.fault("store open failed: \(error.localizedDescription, privacy: .public)")
            modelContainer = (try? MenoSchema.makeContainer(inMemory: true)) ?? { fatalError("SwiftData unavailable") }()
        }
        store = MenoStore(container: modelContainer)
        subscription = SubscriptionManager()
        health = HealthService()
        notifications = NotificationService()
        watch = WatchBridge()
        nightWatch = NightWatchController()
        surges = SurgeController()
        surges.container = self
        health.container = self
        watch.container = self
        nightWatch.container = self
        #if DEBUG
        DemoData.applyLaunchArguments(to: self)
        #endif
    }

    func start() {
        subscription.start()
        watch.activate()
        importPendingSurges()
        health.startIfAuthorized()
        nightWatch.reconcile()
        refreshSnapshot()
    }

    // MARK: Writes with side effects

    /// Saves a surge, mirrors it to Apple Health and refreshes widgets/Watch.
    @discardableResult
    func log(_ record: SurgeRecord) -> SurgeEvent {
        let event = store.insertSurge(record)
        Task { await health.write(event: event) }
        refreshSnapshot()
        return event
    }

    func update(_ event: SurgeEvent, with record: SurgeRecord) {
        event.apply(record)
        store.save()
        Task { await health.write(event: event) }
        refreshSnapshot()
    }

    func delete(_ event: SurgeEvent) {
        let sample = event.hkSampleUUID
        store.deleteSurge(event)
        if let sample { Task { await health.deleteSample(uuid: sample) } }
        refreshSnapshot()
    }

    /// Surges captured by the Watch or an extension while the app wasn't running.
    func importPendingSurges() {
        for p in PendingSurgeQueue.drain() { log(p.record) }
    }

    // MARK: Snapshot

    func refreshSnapshot() {
        let today = DayKey.today()
        let window = DayWindow(lastDays: 7, endingOn: today)
        let stats = StatsCalculator.compute(window: window, surges: store.surgeRecords(in: window), checkIns: [])
        var appt: MenoSnapshot.Appointment?
        if let a = store.nextAppointment() {
            appt = .init(date: a.date, readiness: VisitReadinessCalculator.readiness(store: store, appointment: a).score)
        }
        let snap = MenoSnapshot(
            todayCount: stats.days.last?.count ?? 0,
            last7: stats.days.map { .init(day: $0.day, count: $0.count, level: $0.level) },
            appointment: appt,
            activeSurge: ActiveSurgeStore.read(),
            isPro: subscription.isPro,
            updatedAt: .now)
        SnapshotStore.write(snap)
        watch.send(snapshot: snap)
    }

    // MARK: Delete all

    func deleteAllData() {
        store.deleteAll()
        ActiveSurgeStore.clear()
        _ = PendingSurgeQueue.drain()
        notifications.cancelAll()
        refreshSnapshot()
    }
}
