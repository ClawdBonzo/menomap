import SwiftUI

struct NightWatchSettingsView: View {
    @Environment(AppContainer.self) private var container
    @Environment(MenoStore.self) private var store
    @State private var bedReminder = UserDefaults.standard.bool(forKey: "meno.nightwatch.remind")

    var body: some View {
        let p = store.profile()
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "moon.stars.fill").font(.largeTitle).foregroundStyle(MenoTheme.nightInk)
                    Text("A one-tap night sweat button on your Lock Screen, from bedtime until morning. No unlocking, no bright screen at 3am.")
                        .font(.body)
                }
                .padding(.vertical, 6)
                Toggle("Night Watch", isOn: Binding(get: { p.nightWatchOn }, set: { on in
                    p.nightWatchOn = on
                    store.save()
                    if on, container.nightWatch.isNearBedtime() { container.nightWatch.arm() }
                    if !on { container.nightWatch.disarm() }
                    reschedule()
                }))
            }
            if p.nightWatchOn {
                Section("Times") {
                    DatePicker("Bedtime", selection: time(hour: \.bedtimeHour, minute: \.bedtimeMinute), displayedComponents: .hourAndMinute)
                    DatePicker("Wake", selection: time(hour: \.wakeHour, minute: \.wakeMinute), displayedComponents: .hourAndMinute)
                    Toggle("Bedtime reminder to arm it", isOn: Binding(get: { bedReminder }, set: { on in
                        bedReminder = on
                        UserDefaults.standard.set(on, forKey: "meno.nightwatch.remind")
                        Task {
                            let ok = on ? await container.notifications.requestPermission() : true
                            if ok { reschedule() }
                        }
                    }))
                }
                Section {
                    Button(container.nightWatch.isArmed ? "Night Watch is on" : "Turn on for tonight") { container.nightWatch.arm() }
                        .disabled(container.nightWatch.isArmed)
                    if container.nightWatch.isArmed {
                        Button("Turn off until tomorrow", role: .destructive) { container.nightWatch.disarm() }
                    }
                }
                Section {
                    Text("It turns on by itself when you do your evening check-in or open MenoMap near bedtime.")
                    Text("Fully automatic: in the Shortcuts app, tap Automation → + → Sleep (or Focus → Sleep) → When turning on → Arm Night Watch.")
                } header: { Text("How it turns on") }
                .font(.subheadline)
                .foregroundStyle(MenoTheme.inkSecondary)
            }
        }
        .menoScreen()
        .navigationTitle("Night Watch")
    }

    private func time(hour: ReferenceWritableKeyPath<UserProfile, Int>, minute: ReferenceWritableKeyPath<UserProfile, Int>) -> Binding<Date> {
        let p = store.profile()
        return Binding(
            get: { Calendar.current.date(from: DateComponents(hour: p[keyPath: hour], minute: p[keyPath: minute])) ?? .now },
            set: { d in
                let c = Calendar.current.dateComponents([.hour, .minute], from: d)
                p[keyPath: hour] = c.hour ?? 0
                p[keyPath: minute] = c.minute ?? 0
                store.save()
                reschedule()
            })
    }

    private func reschedule() {
        let p = store.profile()
        container.notifications.scheduleNightWatch(hour: p.bedtimeHour, minute: p.bedtimeMinute,
                                                   enabled: p.nightWatchOn && bedReminder)
    }
}
