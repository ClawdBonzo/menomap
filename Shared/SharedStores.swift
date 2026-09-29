import Foundation
import WidgetKit
import MenoCore

// Small App Group stores shared by the app, the widget extension and intents.
// Only counts, levels and timestamps live here: never notes, medication names or scores.

private let groupDefaults = UserDefaults(suiteName: MenoShared.appGroupID) ?? .standard

enum SnapshotStore {
    static func write(_ snapshot: MenoSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        groupDefaults.set(data, forKey: MenoShared.snapshotKey)
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func read() -> MenoSnapshot {
        guard let data = groupDefaults.data(forKey: MenoShared.snapshotKey),
              let snap = try? JSONDecoder().decode(MenoSnapshot.self, from: data) else { return .empty }
        return snap
    }
}

/// The surge currently running (started from the app, a Control, the Action Button or Siri).
enum ActiveSurgeStore {
    static func read() -> MenoSnapshot.ActiveSurge? {
        guard let data = groupDefaults.data(forKey: MenoShared.activeSurgeKey) else { return nil }
        return try? JSONDecoder().decode(MenoSnapshot.ActiveSurge.self, from: data)
    }

    static func write(_ active: MenoSnapshot.ActiveSurge) {
        if let data = try? JSONEncoder().encode(active) {
            groupDefaults.set(data, forKey: MenoShared.activeSurgeKey)
        }
    }

    static func clear() {
        groupDefaults.removeObject(forKey: MenoShared.activeSurgeKey)
    }
}

/// Surges finished outside the app process, waiting for the app to import them (deduped by id).
enum PendingSurgeQueue {
    static func append(_ record: SurgeRecord) {
        var list = peek()
        guard !list.contains(where: { $0.record.id == record.id }) else { return }
        list.append(PendingSurge(record: record))
        if let data = try? JSONEncoder().encode(list) {
            groupDefaults.set(data, forKey: MenoShared.pendingEventsKey)
        }
    }

    static func peek() -> [PendingSurge] {
        guard let data = groupDefaults.data(forKey: MenoShared.pendingEventsKey),
              let list = try? JSONDecoder().decode([PendingSurge].self, from: data) else { return [] }
        return list
    }

    static func drain() -> [PendingSurge] {
        let list = peek()
        groupDefaults.removeObject(forKey: MenoShared.pendingEventsKey)
        return list
    }
}
