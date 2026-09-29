import Foundation
import HealthKit
import MenoCore

/// Apple Health, read + write (Docs/SPEC_ADDITIONS §3).
///
/// Writes only what the user logged in MenoMap (surges, bleeding), tagged with a sync identifier so edits
/// replace the sample in place. Reads the menopause stage (iOS 27), 90 days of symptoms, sleep and wrist
/// temperature. Never claims a Health number shows a cause.
@MainActor
@Observable
final class HealthService {
    weak var container: AppContainer?
    private let hk = HKHealthStore()
    private var observers: [HKObserverQuery] = []
    private(set) var lastImportCount = 0

    static let eventIDKey = "MenoMapEventID"

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    // MARK: Types

    private var writeTypes: Set<HKSampleType> {
        var s: Set<HKSampleType> = [
            HKCategoryType(.hotFlashes), HKCategoryType(.nightSweats),
            HKCategoryType(.menstrualFlow), HKCategoryType(.intermenstrualBleeding),
        ]
        if #available(iOS 27.0, *) { s.insert(HKCategoryType(.bleedingAfterMenopause)) }
        return s
    }

    /// Other symptoms imported for context (never written).
    static let contextSymptoms: [HKCategoryTypeIdentifier] = [
        .sleepChanges, .moodChanges, .memoryLapse, .fatigue, .rapidPoundingOrFlutteringHeartbeat,
        .vaginalDryness, .bladderIncontinence, .headache, .chills,
    ]

    private var readTypes: Set<HKObjectType> {
        var s: Set<HKObjectType> = [
            HKCategoryType(.hotFlashes), HKCategoryType(.nightSweats), HKCategoryType(.sleepAnalysis),
            HKCategoryType(.menstrualFlow), HKCategoryType(.intermenstrualBleeding),
            HKQuantityType(.appleSleepingWristTemperature),
        ]
        for t in Self.contextSymptoms { s.insert(HKCategoryType(t)) }
        if #available(iOS 27.0, *) {
            s.insert(HKCategoryType(.menopausalState))
            s.insert(HKCategoryType(.bleedingAfterMenopause))
        }
        return s
    }

    // MARK: Authorization

    /// Asks once (the system sheet). Returns true when the sheet completed; read access can't be inspected.
    func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }
        do {
            try await hk.requestAuthorization(toShare: writeTypes, read: readTypes)
            container?.store.profile().healthKitOn = true
            container?.store.save()
            return true
        } catch {
            MenoLog.health.error("auth failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    private var enabled: Bool {
        isAvailable && (container?.store.profile().healthKitOn ?? false)
    }

    private func canWrite(_ type: HKSampleType) -> Bool {
        hk.authorizationStatus(for: type) == .sharingAuthorized
    }

    func startIfAuthorized() {
        guard enabled else { return }
        startObservers()
        Task {
            await importRecent(days: 14)
            await refreshStage()
            await refreshNights(days: 60)
        }
    }

    // MARK: Write

    func write(event: SurgeEvent) async {
        guard enabled, event.sourceRaw != SurgeSource.healthImport.rawValue else { return }
        let type = HKCategoryType(event.kind == .hotFlash ? .hotFlashes : .nightSweats)
        guard canWrite(type) else { return }
        // Kind changed? Remove the sample of the other type first.
        let otherType = HKCategoryType(event.kind == .hotFlash ? .nightSweats : .hotFlashes)
        if let old = event.hkSampleUUID {
            try? await hk.deleteObjects(of: otherType, predicate: HKQuery.predicateForObject(with: old))
        }
        let start = event.startedAt
        let end = start.addingTimeInterval(TimeInterval(max(event.durationSec, 1)))
        let sample = HKCategorySample(
            type: type,
            value: HealthSeverity(intensity: event.intensity).rawValue,
            start: start, end: end,
            metadata: [
                Self.eventIDKey: event.id.uuidString,
                HKMetadataKeySyncIdentifier: "surge-\(event.id.uuidString)",
                HKMetadataKeySyncVersion: NSNumber(value: Int(event.updatedAt.timeIntervalSince1970 * 1000)),
            ])
        do {
            try await hk.save(sample)
            event.hkSampleUUID = sample.uuid
            container?.store.save()
        } catch {
            MenoLog.health.error("write failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Bleeding logged in MenoMap → Apple Health. After menopause (iOS 27) uses the dedicated type.
    func write(bleeding note: CycleNote) async {
        guard enabled else { return }
        let sample: HKCategorySample
        let meta: [String: Any] = [
            Self.eventIDKey: note.id.uuidString,
            HKMetadataKeySyncIdentifier: "bleed-\(note.id.uuidString)",
            HKMetadataKeySyncVersion: NSNumber(value: Int(note.updatedAt.timeIntervalSince1970 * 1000)),
        ]
        let end = note.end ?? note.start.addingTimeInterval(60)
        if note.isPostMenopauseFlag, #available(iOS 27.0, *) {
            let type = HKCategoryType(.bleedingAfterMenopause)
            guard canWrite(type) else { return }
            sample = HKCategorySample(type: type, value: vaginalBleedingValue(note.flow).rawValue, start: note.start, end: end, metadata: meta)
        } else if note.flow == .spotting {
            let type = HKCategoryType(.intermenstrualBleeding)
            guard canWrite(type) else { return }
            sample = HKCategorySample(type: type, value: HKCategoryValue.notApplicable.rawValue, start: note.start, end: end, metadata: meta)
        } else {
            let type = HKCategoryType(.menstrualFlow)
            guard canWrite(type) else { return }
            var m = meta
            m[HKMetadataKeyMenstrualCycleStart] = true
            sample = HKCategorySample(type: type, value: vaginalBleedingValue(note.flow).rawValue, start: note.start, end: end, metadata: m)
        }
        do {
            try await hk.save(sample)
            note.hkSampleUUID = sample.uuid
            container?.store.save()
        } catch {
            MenoLog.health.error("bleeding write failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func vaginalBleedingValue(_ flow: Flow) -> HKCategoryValueVaginalBleeding {
        switch flow {
        case .spotting, .light: .light
        case .medium: .medium
        case .heavy: .heavy
        }
    }

    func deleteSample(uuid: UUID) async {
        guard enabled else { return }
        for type in writeTypes {
            try? await hk.deleteObjects(of: type, predicate: HKQuery.predicateForObject(with: uuid))
        }
    }

    // MARK: Read

    private func isOurs(_ sample: HKSample) -> Bool {
        sample.metadata?[Self.eventIDKey] != nil
            || sample.sourceRevision.source.bundleIdentifier == Bundle.main.bundleIdentifier
    }

    private func samples(_ id: HKCategoryTypeIdentifier, since: Date) async -> [HKCategorySample] {
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: HKCategoryType(id), predicate: HKQuery.predicateForSamples(withStart: since, end: nil))],
            sortDescriptors: [SortDescriptor(\.startDate)])
        return (try? await descriptor.result(for: hk)) ?? []
    }

    /// Imports hot flashes / night sweats logged elsewhere (Health app, other apps) plus context symptoms.
    @discardableResult
    func importRecent(days: Int) async -> Int {
        guard enabled, let container else { return 0 }
        let since = DayKey.today().adding(days: -(days - 1)).startDate()
        var added = 0
        for (id, kind) in [(HKCategoryTypeIdentifier.hotFlashes, SurgeKind.hotFlash), (.nightSweats, .nightSweat)] {
            for s in await samples(id, since: since) where !isOurs(s) {
                guard container.store.surge(hkSampleUUID: s.uuid) == nil,
                      s.value != HKCategoryValueSeverity.notPresent.rawValue else { continue }
                let span = Int(s.endDate.timeIntervalSince(s.startDate))
                let record = SurgeRecord(kind: kind, startedAt: s.startDate,
                                         durationSec: (1...7200).contains(span) ? span : 0,
                                         intensity: HealthSeverity(rawValue: s.value)?.intensity, source: .healthImport)
                let event = container.store.insertSurge(record)
                event.hkSampleUUID = s.uuid
                added += 1
            }
        }
        var contextIDs = Self.contextSymptoms
        if #available(iOS 27.0, *) { contextIDs.append(.bleedingAfterMenopause) }
        for id in contextIDs {
            for s in await samples(id, since: since) where !isOurs(s) {
                guard !container.store.hasHealthSymptom(sampleUUID: s.uuid),
                      s.value != HKCategoryValueSeverity.notPresent.rawValue else { continue }
                container.store.context.insert(HealthSymptom(typeRaw: id.rawValue, date: s.startDate, severityRaw: s.value, hkSampleUUID: s.uuid))
            }
        }
        container.store.save()
        lastImportCount = added
        if added > 0 { container.refreshSnapshot() }
        return added
    }

    /// Menopause stage from Apple Health (iOS 27). Never overrides a stage the user picked.
    func refreshStage() async {
        guard enabled, let container else { return }
        guard #available(iOS 27.0, *) else { return }
        let profile = container.store.profile()
        guard profile.stageSource != "user" else { return }
        let latest = await samples(.menopausalState, since: .distantPast).last
        guard let latest, let value = HKCategoryValueMenopausalState(rawValue: latest.value) else { return }
        switch value {
        case .perimenopause: profile.stage = .perimenopause
        case .menopause: profile.stage = .menopause
        case .none: return
        @unknown default: return
        }
        profile.stageSource = "health"
        container.store.save()
    }

    /// Nightly sleep minutes and wrist-temperature deviation, cached per morning.
    func refreshNights(days: Int) async {
        guard enabled, let container else { return }
        let since = DayKey.today().adding(days: -days).startDate()

        // Sleep: sum asleep stages per source per morning; take the largest source (Watch vs phone overlap).
        let asleep: Set<Int> = [HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue, HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                                HKCategoryValueSleepAnalysis.asleepDeep.rawValue, HKCategoryValueSleepAnalysis.asleepREM.rawValue]
        var bySource: [DayKey: [String: Double]] = [:]
        for s in await samples(.sleepAnalysis, since: since) where asleep.contains(s.value) {
            let morning = DayKey(s.endDate)
            bySource[morning, default: [:]][s.sourceRevision.source.bundleIdentifier, default: 0] += s.endDate.timeIntervalSince(s.startDate)
        }
        for (morning, sources) in bySource {
            let night = container.store.healthNight(for: morning)
            night.minutesAsleep = Int((sources.values.max() ?? 0) / 60)
            night.updatedAt = .now
        }

        // Wrist temperature: HealthKit stores absolute °C; deviation = value − median of the window.
        let tempDescriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: HKQuantityType(.appleSleepingWristTemperature),
                                         predicate: HKQuery.predicateForSamples(withStart: since, end: nil))],
            sortDescriptors: [SortDescriptor(\.startDate)])
        let temps = ((try? await tempDescriptor.result(for: hk)) ?? []).map {
            (DayKey($0.endDate), $0.quantity.doubleValue(for: .degreeCelsius()))
        }
        if temps.count >= 5 {
            let sorted = temps.map(\.1).sorted()
            let median = sorted[sorted.count / 2]
            for (morning, value) in temps {
                let night = container.store.healthNight(for: morning)
                night.wristTempDelta = ((value - median) * 100).rounded() / 100
            }
        }
        container.store.save()
    }

    // MARK: Background updates

    private func startObservers() {
        guard observers.isEmpty else { return }
        var ids: [HKCategoryTypeIdentifier] = [.hotFlashes, .nightSweats]
        if #available(iOS 27.0, *) { ids.append(.menopausalState) }
        for id in ids {
            let type = HKCategoryType(id)
            let q = HKObserverQuery(sampleType: type, predicate: nil) { [weak self] _, completion, error in
                guard error == nil else { completion(); return }
                Task { @MainActor in
                    await self?.importRecent(days: 3)
                    await self?.refreshStage()
                    completion()
                }
            }
            hk.execute(q)
            observers.append(q)
            hk.enableBackgroundDelivery(for: type, frequency: .hourly) { _, _ in }
        }
    }
}
