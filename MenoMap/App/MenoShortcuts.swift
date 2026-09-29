import AppIntents

/// Siri / Shortcuts / Spotlight phrases. Also makes StartSurgeIntent available to the Action Button.
struct MenoShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: StartSurgeIntent(kind: .hotFlash),
                    phrases: ["Log a hot flash in \(.applicationName)",
                              "Start a hot flash in \(.applicationName)",
                              "I'm having a hot flash in \(.applicationName)",
                              "Start a surge in \(.applicationName)"],
                    shortTitle: "Hot flash", systemImageName: "flame")
        AppShortcut(intent: StartSurgeIntent(kind: .nightSweat),
                    phrases: ["Log a night sweat in \(.applicationName)",
                              "Start a night sweat in \(.applicationName)"],
                    shortTitle: "Night sweat", systemImageName: "moon.haze")
        AppShortcut(intent: EndSurgeIntent(),
                    phrases: ["End my surge in \(.applicationName)", "Stop the \(.applicationName) timer"],
                    shortTitle: "End surge", systemImageName: "stop.circle")
    }
}
