import SwiftUI
import MenoCore

struct AppRootView: View {
    @Environment(AppContainer.self) private var container
    @Environment(AppRouter.self) private var router
    @Environment(MenoStore.self) private var store

    var body: some View {
        Group {
            if store.profile().onboardingDone {
                MainTabs()
            } else {
                OnboardingView()
            }
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
        }
    }
}
