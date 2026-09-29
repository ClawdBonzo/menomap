import Foundation
import WatchConnectivity
import MenoCore

/// Phone side of WatchConnectivity. The Watch sends finished surges; the phone is the single source of truth
/// and the only writer to Apple Health, so there are never duplicate samples.
@MainActor
final class WatchBridge: NSObject {
    weak var container: AppContainer?
    private var lastSent: MenoSnapshot?

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Pushes the latest snapshot to the Watch's application context (latest-wins, survives restarts).
    func send(snapshot: MenoSnapshot) {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated,
              WCSession.default.isPaired, WCSession.default.isWatchAppInstalled, snapshot != lastSent else { return }
        lastSent = snapshot
        try? WCSession.default.updateApplicationContext(WatchMessage.snapshot(snapshot).userInfo())
    }

    fileprivate func receive(_ userInfo: [String: Any]) {
        guard let message = WatchMessage(userInfo: userInfo) else { return }
        switch message {
        case .surge(let record):
            guard container?.store.surge(id: record.id) == nil else { return }
            container?.log(record)
            MenoLog.watch.info("surge received from Watch")
        case .snapshot:
            break
        }
    }
}

extension WatchBridge: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {}
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) { session.activate() }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        let box = UncheckedBox(userInfo)
        Task { @MainActor in self.receive(box.value) }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        let box = UncheckedBox(message)
        Task { @MainActor in self.receive(box.value) }
    }
}

/// Carries a non-Sendable WatchConnectivity payload onto the main actor.
struct UncheckedBox<T>: @unchecked Sendable {
    let value: T
    init(_ value: T) { self.value = value }
}
