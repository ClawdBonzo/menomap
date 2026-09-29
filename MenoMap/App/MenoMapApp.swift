import SwiftUI
import MenoCore

@main
struct MenoMapApp: App {
    @State private var container = AppContainer.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Touch the container early so App Intents launched in the background find the surge handler.
        _ = AppContainer.shared
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environment(container)
                .environment(container.store)
                .environment(container.router)
                .environment(container.subscription)
                .environment(container.surges)
                .modelContainer(container.store.container)
                .onOpenURL { container.router.handle(url: $0) }
                .task { container.start() }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            container.surges.reconcile()
            container.importPendingSurges()
            container.health.startIfAuthorized()
            container.refreshSnapshot()
        }
    }
}
