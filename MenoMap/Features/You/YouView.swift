import SwiftUI
import StoreKit
import MenoCore

struct YouView: View {
    @Environment(AppContainer.self) private var container
    @Environment(MenoStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(SubscriptionManager.self) private var subscription

    @State private var showRedeem = false
    @State private var remindOn = false
    @State private var remindTime = Date.now
    @State private var heatReportOn = UserDefaults.standard.bool(forKey: "meno.heatreport.notify")

    var body: some View {
        let _ = store.revision
        let profile = store.profile()
        NavigationStack {
            List {
                Section {
                    TextField("First name (optional)", text: Binding(get: { profile.firstName ?? "" },
                                                                    set: { profile.firstName = $0.isEmpty ? nil : $0; store.save() }))
                    Picker("Stage", selection: Binding<MenopauseStage?>(
                        get: { profile.stage },
                        set: { profile.stage = $0; profile.stageSource = "user"; store.save() })) {
                        Text("Not set").tag(MenopauseStage?.none)
                        ForEach(MenopauseStage.allCases, id: \.self) { Text(Copy.stage($0)).tag(Optional($0)) }
                    }
                } header: { Text("You") } footer: {
                    if profile.stageSource == "health" { Text("Stage from Apple Health.") }
                }

                Section("Tracking") {
                    NavigationLink { TrackedMetricsView() } label: { Label("Check-in questions", systemImage: "slider.horizontal.3") }
                    NavigationLink { MedicationListView() } label: { Label("Medications", systemImage: "pills") }
                    NavigationLink { CycleView() } label: { Label("Cycle", systemImage: "drop") }
                    Button { router.present(.surgeSetup) } label: { Label("One tap away", systemImage: "hand.tap") }
                    Picker(selection: Binding(get: { profile.voice }, set: { profile.voice = $0; store.save() })) {
                        Text("Wry").tag(VoiceStyle.wry)
                        Text("Straight").tag(VoiceStyle.straight)
                    } label: {
                        Label("Voice for stats and cards", systemImage: "text.quote")
                    }
                }

                HealthSection()

                Section("Reminders") {
                    Toggle(isOn: Binding(get: { remindOn }, set: setReminder)) { Label("Evening check-in", systemImage: "bell") }
                    if remindOn {
                        DatePicker("Time", selection: Binding(get: { remindTime }, set: { remindTime = $0; setReminder(true) }),
                                   displayedComponents: .hourAndMinute)
                    }
                    Toggle(isOn: Binding(get: { heatReportOn }, set: { on in
                        heatReportOn = on
                        UserDefaults.standard.set(on, forKey: "meno.heatreport.notify")
                        Task {
                            let allowed = on ? await container.notifications.requestPermission() : true
                            if allowed { container.notifications.scheduleHeatReport(enabled: on) }
                        }
                    })) { Label("Monthly Heat Report", systemImage: "calendar") }
                }

                Section("Learn") {
                    NavigationLink { LearnView() } label: { Label("Library and questions", systemImage: "book") }
                }

                Section {
                    if subscription.isPro {
                        Label("MenoMap Pro is active", systemImage: "checkmark.seal.fill").foregroundStyle(MenoTheme.teal)
                        Link(destination: URL(string: "https://apps.apple.com/account/subscriptions") ?? LegalLinks.appStore) {
                            Label("Manage subscription", systemImage: "creditcard")
                        }
                    } else {
                        Button { router.present(.paywall(.settings)) } label: { Label("MenoMap Pro", systemImage: "sparkles") }
                    }
                    Button { Task { await subscription.restore() } } label: { Label("Restore purchases", systemImage: "arrow.clockwise") }
                    Button { showRedeem = true } label: { Label("Redeem a code", systemImage: "giftcard") }
                } header: { Text("MenoMap Pro") }

                Section("Share") {
                    NavigationLink { TellMyPersonView() } label: { Label("Tell my person", systemImage: "message") }
                    ShareLink(item: LegalLinks.appStore,
                              message: Text("I use MenoMap to log hot flashes and bring notes to my appointments. Code MENOFRIEND gets you 30 days of Pro free.")) {
                        Label("Give a friend 30 days of Pro", systemImage: "gift")
                    }
                }

                Section("Privacy") {
                    NavigationLink { PrivacyView() } label: { Label("What's stored and where", systemImage: "lock") }
                }

                Section("About") {
                    DisclaimerBanner().listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
                    Link("Privacy Policy", destination: LegalLinks.privacy)
                    Link("Terms of Use", destination: LegalLinks.terms)
                    Link("For clinicians", destination: LegalLinks.clinicians)
                    Text("MenoMap \(Bundle.main.shortVersion) · GW Labs").font(.footnote).foregroundStyle(MenoTheme.inkSecondary)
                }

                #if DEBUG
                Section("Debug") {
                    Button("Load demo data") { DemoData.load(into: container); container.refreshSnapshot() }
                    Button("Replay onboarding") { profile.onboardingDone = false; store.save() }
                }
                #endif
            }
            .menoScreen()
            .navigationTitle("You")
            .offerCodeRedemption(isPresented: $showRedeem) { _ in Task { await subscription.refreshEntitlements() } }
            .onAppear {
                remindOn = profile.reminderHour != nil
                remindTime = Calendar.current.date(from: DateComponents(hour: profile.reminderHour ?? 20, minute: profile.reminderMinute)) ?? .now
            }
        }
    }

    private func setReminder(_ on: Bool) {
        let p = store.profile()
        remindOn = on
        if on {
            let c = Calendar.current.dateComponents([.hour, .minute], from: remindTime)
            p.reminderHour = c.hour ?? 20
            p.reminderMinute = c.minute ?? 30
            Task {
                if await container.notifications.requestPermission() {
                    container.notifications.scheduleEveningCheckIn(hour: p.reminderHour ?? 20, minute: p.reminderMinute)
                }
            }
        } else {
            p.reminderHour = nil
            container.notifications.cancelEveningCheckIn()
        }
        store.save()
    }
}

private struct HealthSection: View {
    @Environment(AppContainer.self) private var container
    @Environment(MenoStore.self) private var store
    @State private var working = false
    @State private var message: String?

    var body: some View {
        Section {
            if container.health.isAvailable {
                if store.profile().healthKitOn {
                    Label("Connected", systemImage: "heart.fill").foregroundStyle(MenoTheme.teal)
                    Button {
                        Task {
                            working = true
                            let n = await container.health.importRecent(days: 90)
                            await container.health.refreshNights(days: 90)
                            await container.health.refreshStage()
                            message = String(localized: "Imported \(n) new surges.")
                            working = false
                        }
                    } label: { Label(working ? "Importing…" : "Import from Apple Health again", systemImage: "arrow.down.circle") }
                    .disabled(working)
                } else {
                    Button {
                        Task { if await container.health.requestAuthorization() { container.health.startIfAuthorized() } }
                    } label: { Label("Connect Apple Health", systemImage: "heart") }
                }
            } else {
                Text("Apple Health isn't available on this device.").foregroundStyle(MenoTheme.inkSecondary)
            }
            if let message { Text(message).font(.footnote).foregroundStyle(MenoTheme.inkSecondary) }
        } header: { Text("Apple Health") } footer: {
            Text("To change what MenoMap can read or write: Settings → Health → Data Access & Devices → MenoMap.")
        }
    }
}

struct TrackedMetricsView: View {
    @Environment(MenoStore.self) private var store

    var body: some View {
        let profile = store.profile()
        List {
            Section {
                ForEach(TrackedMetric.allCases, id: \.self) { m in
                    Toggle(isOn: Binding(
                        get: { profile.trackedMetrics.contains(m) },
                        set: { on in
                            var set = profile.trackedMetrics
                            if on { set.append(m) } else { set.removeAll { $0 == m } }
                            profile.trackedMetrics = TrackedMetric.allCases.filter { set.contains($0) }
                            store.save()
                        })) {
                        Label(Copy.metric(m), systemImage: Copy.metricSymbol(m))
                    }
                }
            } footer: {
                Text("Turning a question off never deletes past answers.")
            }
        }
        .menoScreen()
        .navigationTitle("Check-in questions")
    }
}

extension Bundle {
    var shortVersion: String { (object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "1.0" }
}
