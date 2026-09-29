import SwiftUI
import WatchConnectivity
import WatchKit
import WidgetKit
import MenoCore

@main
struct MenoMapWatchApp: App {
    @State private var model = WatchModel()

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environment(model)
                .onAppear { model.activate() }
        }
    }
}

/// Watch side: runs a surge locally (no phone screen at 3am) and hands the finished record to the phone,
/// which is the only writer to Apple Health.
@MainActor
@Observable
final class WatchModel: NSObject, WCSessionDelegate {
    var startedAt: Date?
    var kind: SurgeKind = .hotFlash
    var snapshot: MenoSnapshot = .empty
    var pendingRating = false
    var endedSeconds = 0
    private var surgeID = UUID()

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
        if let msg = WatchMessage(userInfo: WCSession.default.receivedApplicationContext), case .snapshot(let s) = msg {
            snapshot = s
        }
    }

    func start(_ k: SurgeKind) {
        kind = k
        surgeID = UUID()
        startedAt = .now
        WKInterfaceDevice.current().play(.start)
    }

    func end() {
        guard let s = startedAt else { return }
        endedSeconds = max(Int(Date.now.timeIntervalSince(s)), 1)
        pendingRating = true
        WKInterfaceDevice.current().play(.stop)
    }

    func save(intensity: Int?) {
        guard let s = startedAt else { return }
        let record = SurgeRecord(id: surgeID, kind: kind, startedAt: s, durationSec: endedSeconds, intensity: intensity, source: .watch)
        // transferUserInfo is queued and delivered even if the phone is asleep or out of range right now.
        if WCSession.default.activationState == .activated {
            WCSession.default.transferUserInfo(WatchMessage.surge(record).userInfo())
        }
        snapshot.todayCount += 1
        Self.storeForComplications(snapshot)
        startedAt = nil
        pendingRating = false
        WKInterfaceDevice.current().play(.success)
    }

    /// Complications read today's count from the Watch-side App Group.
    static func storeForComplications(_ s: MenoSnapshot) {
        if let data = try? JSONEncoder().encode(s) {
            UserDefaults(suiteName: MenoShared.appGroupID)?.set(data, forKey: MenoShared.snapshotKey)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    func discard() {
        startedAt = nil
        pendingRating = false
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {}

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext context: [String: Any]) {
        guard let msg = WatchMessage(userInfo: context), case .snapshot(let s) = msg else { return }
        Task { @MainActor in
            self.snapshot = s
            Self.storeForComplications(s)
        }
    }
}

struct WatchRootView: View {
    @Environment(WatchModel.self) private var model

    var body: some View {
        if model.pendingRating {
            WatchRateView()
        } else if model.startedAt != nil {
            WatchSessionView()
        } else {
            WatchHomeView()
        }
    }
}

private let teal = Color(red: 0.32, green: 0.72, blue: 0.68)
private let ember = Color(red: 0.94, green: 0.48, blue: 0.30)
private let nightInk = Color(red: 0.79, green: 0.31, blue: 0.23)

struct WatchHomeView: View {
    @Environment(WatchModel.self) private var model

    private var night: Bool {
        let h = Calendar.current.component(.hour, from: .now)
        return h >= 21 || h < 7
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Button { model.start(night ? .nightSweat : .hotFlash) } label: {
                    VStack(spacing: 4) {
                        Image(systemName: night ? "moon.haze.fill" : "flame.fill").font(.title2)
                        Text(night ? "Night sweat" : "Surge").font(.headline)
                    }
                    .frame(maxWidth: .infinity, minHeight: 90)
                }
                .buttonStyle(.borderedProminent)
                .tint(night ? nightInk : teal)
                .handGestureShortcut(.primaryAction)

                Button(night ? "Hot flash" : "Night sweat") { model.start(night ? .hotFlash : .nightSweat) }
                    .font(.footnote)

                Text("Today: \(model.snapshot.todayCount)")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("MenoMap")
    }
}

struct WatchSessionView: View {
    @Environment(WatchModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            let secs = Int(ctx.date.timeIntervalSince(model.startedAt ?? ctx.date))
            let t = Double(secs % 12)
            let phase = t < 4 ? String(localized: "In") : t < 8 ? String(localized: "Hold") : String(localized: "Out")
            VStack(spacing: 6) {
                Text(String(format: "%d:%02d", secs / 60, secs % 60))
                    .font(.system(size: 40, weight: .semibold, design: .serif).monospacedDigit())
                    .foregroundStyle(model.kind == .nightSweat ? nightInk : .primary)
                ZStack {
                    if !reduceMotion {
                        Circle().fill(teal.opacity(0.2))
                            .scaleEffect(t < 4 ? 0.6 + 0.1 * t : t < 8 ? 1 : 1 - 0.1 * (t - 8))
                            .animation(.easeInOut(duration: 1), value: secs)
                    }
                    Text(phase).font(.headline)
                }
                .frame(height: 84)
                Button("End") { model.end() }
                    .tint(teal)
                    .handGestureShortcut(.primaryAction)
                    .accessibilityHint(Text("Double tap your fingers to end"))
            }
            .onChange(of: secs) { _, s in
                // A gentle tap at each breathing phase change.
                if s % 4 == 0 { WKInterfaceDevice.current().play(.click) }
            }
        }
    }
}

struct WatchRateView: View {
    @Environment(WatchModel.self) private var model
    @State private var crown = 3.0

    static func word(_ i: Int) -> String {
        switch i {
        case 1: String(localized: "Mild")
        case 2: String(localized: "Noticeable")
        case 3: String(localized: "Strong")
        case 4: String(localized: "Very strong")
        default: String(localized: "Intense")
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            Text("How strong?").font(.headline)
            Text("Turn the Crown").font(.caption2).foregroundStyle(.secondary)
            Text("\(Int(crown.rounded()))").font(.system(size: 44, weight: .semibold, design: .serif).monospacedDigit())
                .foregroundStyle(ember)
                .focusable()
                .digitalCrownRotation($crown, from: 1, through: 5, by: 1, sensitivity: .low, isContinuous: false, isHapticFeedbackEnabled: true)
            Text(Self.word(Int(crown.rounded()))).font(.footnote).foregroundStyle(.secondary)
            Button("Save") { model.save(intensity: Int(crown.rounded())) }
                .tint(teal)
                .handGestureShortcut(.primaryAction)
            Button("Skip rating") { model.save(intensity: nil) }.font(.footnote)
        }
    }
}
