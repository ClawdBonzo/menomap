import SwiftUI
import MenoCore

@main
struct MenoMapApp: App {
    @State private var container = AppContainer.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Touch the container early so App Intents launched in the background find the surge handler.
        _ = AppContainer.shared
        Self.styleNavigationBars()
    }

    /// New York serif for navigation titles (Docs/MenoMap_Visual_Identity.md → Type).
    private static func styleNavigationBars() {
        func serif(_ style: UIFont.TextStyle, _ weight: UIFont.Weight) -> UIFont {
            let base = UIFont.preferredFont(forTextStyle: style)
            let d = base.fontDescriptor.withDesign(.serif)?.addingAttributes([.traits: [UIFontDescriptor.TraitKey.weight: weight]])
            return d.map { UIFont(descriptor: $0, size: 0) } ?? base
        }
        let a = UINavigationBar.appearance()
        a.largeTitleTextAttributes = [.font: serif(.largeTitle, .semibold)]
        a.titleTextAttributes = [.font: serif(.headline, .semibold)]
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
            container.nightWatch.reconcile()
            container.importPendingSurges()
            container.health.startIfAuthorized()
            container.refreshSnapshot()
        }
    }
}
