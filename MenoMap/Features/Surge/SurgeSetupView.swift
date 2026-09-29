import SwiftUI
import WatchConnectivity

/// "Put Surge one tap away": Control Center, Lock Screen, Action Button, widget, Watch.
/// iOS doesn't let apps add these themselves, so each step shows exactly where to tap.
struct SurgeSetupView: View {
    var isOnboarding: Bool
    var onDone: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var expanded: Place? = .controlCenter

    enum Place: String, CaseIterable, Identifiable {
        case controlCenter, lockScreen, actionButton, widget, watch, siri
        var id: String { rawValue }
    }

    var body: some View {
        if isOnboarding {
            content
        } else {
            NavigationStack {
                ScrollView { content.padding(20) }
                    .menoScreen()
                    .navigationTitle("One tap away")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Put Surge one tap away")
                .font(MenoTheme.headline(.largeTitle)).foregroundStyle(MenoTheme.ink)
            Text("Mid-flash, you don't want to hunt for an app. Add MenoMap where your thumb already is. Each takes about 10 seconds.")
                .font(.body).foregroundStyle(MenoTheme.inkSecondary)

            ForEach(Place.allCases) { place in
                PlaceRow(place: place, expanded: expanded == place) {
                    withAnimation(.easeInOut(duration: 0.2)) { expanded = expanded == place ? nil : place }
                }
            }

            if isOnboarding {
                Button("Continue") { onDone?() }
                    .buttonStyle(.menoPrimary)
                    .padding(.top, 8)
                Text("You can find this again in You → One tap away.")
                    .font(.footnote).foregroundStyle(MenoTheme.inkSecondary)
            }
        }
    }
}

private struct PlaceRow: View {
    let place: SurgeSetupView.Place
    let expanded: Bool
    let toggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: toggle) {
                HStack(spacing: 14) {
                    Image(systemName: symbol)
                        .font(.title3).foregroundStyle(MenoTheme.teal)
                        .frame(width: 44, height: 44)
                        .background(MenoTheme.tealSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).font(.headline).foregroundStyle(MenoTheme.ink)
                        Text(subtitle).font(.subheadline).foregroundStyle(MenoTheme.inkSecondary)
                    }
                    Spacer()
                    if place == .watch, watchInstalled {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(MenoTheme.teal)
                    }
                    Image(systemName: expanded ? "chevron.up" : "chevron.down").foregroundStyle(MenoTheme.inkSecondary)
                }
            }
            .buttonStyle(.plain)
            if expanded {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { i, s in
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(i + 1)")
                                .font(.caption.weight(.bold).monospacedDigit())
                                .foregroundStyle(MenoTheme.onTeal)
                                .frame(width: 22, height: 22)
                                .background(MenoTheme.teal, in: Circle())
                            Text(s).font(.subheadline).foregroundStyle(MenoTheme.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.leading, 4)
            }
        }
        .padding(14)
        .background(MenoTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(MenoTheme.hairline))
    }

    private var watchInstalled: Bool {
        WCSession.isSupported() && WCSession.default.activationState == .activated && WCSession.default.isWatchAppInstalled
    }

    private var symbol: String {
        switch place {
        case .controlCenter: "switch.2"
        case .lockScreen: "lock.iphone"
        case .actionButton: "button.vertical.left.press"
        case .widget: "square.grid.2x2"
        case .watch: "applewatch"
        case .siri: "mic"
        }
    }

    private var title: LocalizedStringKey {
        switch place {
        case .controlCenter: "Control Center"
        case .lockScreen: "Lock Screen"
        case .actionButton: "Action Button"
        case .widget: "Home Screen widget"
        case .watch: "Apple Watch"
        case .siri: "Siri"
        }
    }

    private var subtitle: LocalizedStringKey {
        switch place {
        case .controlCenter: "Swipe down, tap, done"
        case .lockScreen: "Start without unlocking"
        case .actionButton: "iPhone 15 Pro and later"
        case .widget: "Big button on your Home Screen"
        case .watch: "Log at 3am without lighting up your phone"
        case .siri: "\"Log a hot flash in MenoMap\""
        }
    }

    private var steps: [LocalizedStringKey] {
        switch place {
        case .controlCenter:
            ["Swipe down from the top-right corner.", "Tap + at the top left, then Add a Control.", "Search MenoMap and pick Start a surge."]
        case .lockScreen:
            ["Touch and hold the Lock Screen, then tap Customize.", "Tap Lock Screen, then tap a control at the bottom.", "Pick MenoMap → Start a surge."]
        case .actionButton:
            ["Open Settings → Action Button.", "Swipe to Controls, tap Choose a Control.", "Pick MenoMap → Start a surge."]
        case .widget:
            ["Touch and hold the Home Screen, tap Edit, then Add Widget.", "Search MenoMap.", "Pick the Surge button or the 7-day heat map."]
        case .watch:
            ["Open the Watch app on your iPhone.", "Scroll to Available Apps and tap Install next to MenoMap.", "Add the MenoMap complication to your watch face."]
        case .siri:
            ["Say \"Log a hot flash in MenoMap\" or \"Start a night sweat in MenoMap\".", "The timer starts on your Lock Screen. Tap End when it eases."]
        }
    }
}
