import SwiftUI
import MenoCore

struct AppRootView: View {
    @Environment(AppContainer.self) private var container
    @Environment(AppRouter.self) private var router
    @Environment(MenoStore.self) private var store

    /// Reads `revision` so finishing onboarding (which saves) always swaps the screen. Observing the profile model
    /// alone missed the change after a fresh install, leaving "Just look around" looking dead.
    private var onboardingDone: Bool {
        _ = store.revision
        return store.profile().onboardingDone
    }

    var body: some View {
        Group {
            #if DEBUG
            if let kind = Showcase.kind {
                ShowcaseView(kind: kind)
            } else if onboardingDone {
                MainTabs()
            } else {
                OnboardingView()
            }
            #else
            if onboardingDone {
                MainTabs()
            } else {
                OnboardingView()
            }
            #endif
        }
        .sheet(item: Binding(get: { router.sheet.flatMap { $0.isFullScreen ? nil : $0 } },
                             set: { router.sheet = $0 })) { sheet in
            SheetHost(sheet: sheet)
        }
        .fullScreenCover(item: Binding(get: { router.sheet.flatMap { $0.isFullScreen ? $0 : nil } },
                                       set: { router.sheet = $0 })) { sheet in
            SheetHost(sheet: sheet)
        }
        .tint(MenoTheme.teal)
        .overlay(alignment: .bottom) { ToastView() }
    }
}

struct ToastView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        if let text = router.toast {
            Text(text)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MenoTheme.onTeal)
                .padding(.horizontal, 18).padding(.vertical, 12)
                .background(MenoTheme.teal, in: Capsule())
                .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
                .padding(.bottom, 100)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .task(id: text) {
                    try? await Task.sleep(for: .seconds(2.6))
                    withAnimation { router.toast = nil }
                }
                .accessibilityAddTraits(.updatesFrequently)
                .onAppear { UIAccessibility.post(notification: .announcement, argument: text) }
        }
    }
}

struct MainTabs: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.tab) {
            Tab("Today", systemImage: "sun.horizon", value: AppTab.today) { TodayView() }
            Tab("Week", systemImage: "square.grid.3x3.middle.filled", value: AppTab.week) { WeekView() }
            Tab("Visit", systemImage: "doc.text", value: AppTab.visit) { VisitView() }
            Tab("You", systemImage: "person.crop.circle", value: AppTab.you) { YouView() }
        }
    }
}

/// Every modal in one place so intents/deep links can present any of them.
struct SheetHost: View {
    let sheet: AppSheet

    var body: some View {
        switch sheet {
        case .surge(let kind): SurgeSessionView(initialKind: kind)
        case .afterTheFact: AfterTheFactView()
        case .checkIn: CheckInView()
        case .rate(let id): RateSurgeView(surgeID: id)
        case .paywall(let trigger): PaywallView(trigger: trigger)
        case .surgeSetup: SurgeSetupView(isOnboarding: false)
        case .medication(let id): MedicationEditView(medicationID: id)
        case .bleeding: BleedingLogView()
        case .samplePreview: SamplePreviewView()
        case .medications: MedicationsSheet()
        }
    }
}
