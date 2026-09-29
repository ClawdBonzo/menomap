import SwiftUI
import MenoCore

enum MedicationText {
    static func schedule(_ m: Medication) -> String {
        switch m.schedule {
        case .daily: return String(localized: "Every day")
        case .asNeeded: return String(localized: "As needed")
        case .days:
            let symbols = Calendar.current.shortWeekdaySymbols
            return m.weekdays.sorted().compactMap { symbols.indices.contains($0 - 1) ? symbols[$0 - 1] : nil }.joined(separator: ", ")
        }
    }

    static func isDueToday(_ m: Medication) -> Bool {
        switch m.schedule {
        case .daily, .asNeeded: true
        case .days: m.weekdays.contains(DayKey.today().weekday())
        }
    }
}

enum MedicationCopy {
    static var safety: String {
        String(localized: "MenoMap cannot tell you to start, stop, or change a medicine. Bring your list to a clinician.")
    }
}

/// Medication list as a sheet (opened from a dose reminder).
struct MedicationsSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            MedicationListView()
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
        }
    }
}

struct MedicationListView: View {
    @Environment(MenoStore.self) private var store
    @Environment(AppRouter.self) private var router

    var body: some View {
        let _ = store.revision
        let meds = store.medications()
        let profile = store.profile()
        List {
            Section {
                Text(MedicationCopy.safety).font(.footnote).foregroundStyle(MenoTheme.inkSecondary)
            }
            if meds.isEmpty {
                Section {
                    EmptyState(systemImage: "pills", title: "No medications yet", message: "Add what you take, including HRT, non-hormonal options and supplements.")
                    Toggle("I don't take anything right now", isOn: Binding(
                        get: { profile.medicationsConfirmedNone },
                        set: { profile.medicationsConfirmedNone = $0; store.save() }))
                }
            }
            ForEach(meds) { med in
                MedicationRow(med: med)
                    .contentShape(Rectangle())
                    .onTapGesture { router.present(.medication(med.id)) }
            }
        }
        .menoScreen()
        .navigationTitle("Medications")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { router.present(.medication(nil)) } label: { Label("Add", systemImage: "plus") }
            }
        }
    }
}

private struct MedicationRow: View {
    let med: Medication
    @Environment(MenoStore.self) private var store

    var body: some View {
        let todayDoses = store.doses().filter { $0.medicationID == med.id && DayKey($0.takenAt) == .today() }
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(med.name).font(.headline).foregroundStyle(MenoTheme.ink)
                    Text([Copy.medCategory(med.category), med.doseText, MedicationText.schedule(med), med.scheduleText].filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.subheadline).foregroundStyle(MenoTheme.inkSecondary)
                    Text("Since \(med.startDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption).foregroundStyle(MenoTheme.inkSecondary)
                }
                Spacer()
                if med.endDate != nil { Text("Stopped").font(.caption.weight(.semibold)).foregroundStyle(MenoTheme.inkSecondary) }
            }
            if med.endDate == nil, MedicationText.isDueToday(med) {
                if let last = todayDoses.first {
                    Label(last.skipped ? "Skipped today" : "Taken today", systemImage: last.skipped ? "minus.circle" : "checkmark.circle.fill")
                        .font(.subheadline).foregroundStyle(last.skipped ? MenoTheme.inkSecondary : MenoTheme.teal)
                } else {
                    AdaptiveStack(spacing: 8) {
                        Button("Taken") { store.logDose(medicationID: med.id, skipped: false) }.buttonStyle(.menoQuiet)
                        Button("Skipped") { store.logDose(medicationID: med.id, skipped: true) }.buttonStyle(.menoSecondary)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct MedicationEditView: View {
    let medicationID: UUID?

    @Environment(AppContainer.self) private var container
    @Environment(MenoStore.self) private var store
    @Environment(SubscriptionManager.self) private var subscription
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var category: MedicationCategory = .estrogen
    @State private var doseText = ""
    @State private var route = ""
    @State private var schedule = ""
    @State private var start = Date.now
    @State private var stopped = false
    @State private var end = Date.now
    @State private var notes = ""
    @State private var reminderOn = false
    @State private var scheduleKind: MedicationSchedule = .daily
    @State private var weekdays: Set<Int> = []
    @State private var reminderTime = Calendar.current.date(from: DateComponents(hour: 9)) ?? .now
    @State private var loaded = false
    @State private var confirmDelete = false

    private var existing: Medication? { medicationID.flatMap { id in store.medications().first { $0.id == id } } }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name, as on the label", text: $name)
                        .textInputAutocapitalization(.words)
                    Picker("Type", selection: $category) {
                        ForEach(MedicationCategory.allCases, id: \.self) { Text(Copy.medCategory($0)).tag($0) }
                    }
                } footer: {
                    Text("Types only help organize your list and notes.")
                }
                Section {
                    Picker("How often", selection: $scheduleKind) {
                        Text("Every day").tag(MedicationSchedule.daily)
                        Text("Certain days").tag(MedicationSchedule.days)
                        Text("As needed").tag(MedicationSchedule.asNeeded)
                    }
                    .pickerStyle(.segmented)
                    if scheduleKind == .days {
                        WeekdayPicker(selection: $weekdays)
                        Button("Patch, twice a week (Sun & Wed)") {
                            weekdays = [1, 4]
                            if route.isEmpty { route = String(localized: "Patch") }
                        }
                        .font(.subheadline)
                    }
                } header: { Text("Schedule") } footer: {
                    if scheduleKind == .days { Text("Good for patches changed twice a week or weekly treatments.") }
                }
                Section("Details (optional)") {
                    TextField("Dose, e.g. 1 pump or 100 mg", text: $doseText)
                    TextField("How you take it, e.g. gel, patch, tablet", text: $route)
                    TextField("When, e.g. every morning", text: $schedule)
                    DatePicker("Started", selection: $start, in: ...Date.now, displayedComponents: .date)
                    Toggle("I've stopped taking it", isOn: $stopped.animation())
                    if stopped { DatePicker("Stopped", selection: $end, in: start...Date.now, displayedComponents: .date) }
                    TextField("Notes", text: $notes, axis: .vertical)
                }
                Section {
                    Toggle(isOn: Binding(get: { reminderOn }, set: { on in
                        if on && !subscription.isPro { router.present(.paywall(.settings)); return }
                        reminderOn = on
                    })) {
                        HStack {
                            Text("Daily reminder")
                            if !subscription.isPro { ProBadge() }
                        }
                    }
                    if reminderOn && scheduleKind != .asNeeded { DatePicker("Time", selection: $reminderTime, displayedComponents: .hourAndMinute) }
                } footer: {
                    Text("A missed dose is just a note in your log. No lectures.")
                }
                Section { Text(MedicationCopy.safety).font(.footnote).foregroundStyle(MenoTheme.inkSecondary) }
                if existing != nil {
                    Section {
                        Button("Delete medication", role: .destructive) { confirmDelete = true }
                    }
                }
            }
            .menoScreen()
            .navigationTitle(existing == nil ? "Add medication" : "Edit medication")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).fontWeight(.semibold)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .confirmationDialog("Delete this medication and its dose log?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive, action: delete)
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        guard let m = existing else { return }
        name = m.name
        category = m.category
        doseText = m.doseText
        route = m.route
        schedule = m.scheduleText
        start = m.startDate
        stopped = m.endDate != nil
        end = m.endDate ?? .now
        notes = m.notes
        reminderOn = m.reminderOn
        scheduleKind = m.schedule
        weekdays = Set(m.weekdays)
        reminderTime = Calendar.current.date(from: DateComponents(hour: m.reminderHour, minute: m.reminderMinute)) ?? .now
    }

    private func save() {
        let m = existing ?? {
            let n = Medication(name: name, category: category, startDate: start)
            store.context.insert(n)
            return n
        }()
        m.name = name.trimmingCharacters(in: .whitespaces)
        m.categoryRaw = category.rawValue
        m.doseText = doseText
        m.route = route
        m.scheduleText = schedule
        m.startDate = start
        m.endDate = stopped ? end : nil
        m.notes = notes
        m.schedule = scheduleKind
        m.weekdays = weekdays.sorted()
        m.reminderOn = reminderOn && subscription.isPro && !stopped && scheduleKind != .asNeeded
        let c = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        m.reminderHour = c.hour ?? 9
        m.reminderMinute = c.minute ?? 0
        m.updatedAt = .now
        store.profile().medicationsConfirmedNone = false
        store.save()
        if m.reminderOn {
            Task {
                if await container.notifications.requestPermission() { container.notifications.scheduleMedication(m) }
            }
        } else {
            container.notifications.cancelMedication(m.id)
        }
        container.refreshSnapshot()
        dismiss()
    }

    private func delete() {
        guard let m = existing else { return }
        container.notifications.cancelMedication(m.id)
        for d in store.doses() where d.medicationID == m.id { store.context.delete(d) }
        store.context.delete(m)
        store.save()
        dismiss()
    }
}

/// Seven weekday toggles in the locale's order (1 = Sunday … 7 = Saturday, Gregorian).
struct WeekdayPicker: View {
    @Binding var selection: Set<Int>

    var body: some View {
        let cal = Calendar.current
        HStack(spacing: 6) {
            ForEach(0..<7, id: \.self) { i in
                let wd = (cal.firstWeekday - 1 + i) % 7 + 1
                let on = selection.contains(wd)
                Button {
                    if on { selection.remove(wd) } else { selection.insert(wd) }
                } label: {
                    Text(cal.veryShortWeekdaySymbols[wd - 1])
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: MenoTheme.minHit)
                        .foregroundStyle(on ? MenoTheme.onTeal : MenoTheme.ink)
                        .background(on ? MenoTheme.teal : MenoTheme.surface, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(cal.weekdaySymbols[wd - 1]))
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }
}

struct ProBadge: View {
    var body: some View {
        Text("PRO")
            .font(.caption2.weight(.bold))
            .tracking(0.6)
            .foregroundStyle(MenoTheme.onTeal)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(MenoTheme.teal, in: Capsule())
            .accessibilityLabel(Text("Pro feature"))
    }
}

// MARK: - Cycle / bleeding

struct CycleView: View {
    @Environment(MenoStore.self) private var store
    @Environment(AppRouter.self) private var router

    var body: some View {
        let _ = store.revision
        let profile = store.profile()
        List {
            Section {
                Toggle("Track bleeding", isOn: Binding(get: { profile.cycleTrackingOn }, set: { profile.cycleTrackingOn = $0; store.save() }))
                Toggle("I no longer have periods", isOn: Binding(get: { profile.noLongerHasPeriods }, set: { profile.noLongerHasPeriods = $0; store.save() }))
            } footer: {
                Text("MenoMap doesn't predict periods or fertile days.")
            }
            if profile.bleedingNeedsCheck {
                Section { SafetyBanner(title: BleedingCopy.title, message: BleedingCopy.message).listRowInsets(EdgeInsets()) }
            }
            if profile.cycleTrackingOn {
                Section {
                    Button { router.present(.bleeding) } label: { Label("Log bleeding or spotting", systemImage: "plus.circle.fill") }
                }
                Section("History") {
                    let notes = store.cycleNotes()
                    if notes.isEmpty {
                        Text("Nothing logged yet.").foregroundStyle(MenoTheme.inkSecondary)
                    }
                    ForEach(notes) { n in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(n.start.formatted(date: .abbreviated, time: .omitted)).font(.headline)
                            Text([Copy.flow(n.flow), n.note ?? ""].filter { !$0.isEmpty }.joined(separator: " · "))
                                .font(.subheadline).foregroundStyle(MenoTheme.inkSecondary)
                            if n.isPostMenopauseFlag {
                                Text("Flagged to check with a clinician").font(.caption.weight(.semibold)).foregroundStyle(MenoTheme.danger)
                            }
                        }
                    }
                    .onDelete { idx in
                        for i in idx { store.context.delete(notes[i]) }
                        store.save()
                    }
                }
            }
        }
        .menoScreen()
        .navigationTitle("Cycle")
    }
}

struct BleedingLogView: View {
    @Environment(AppContainer.self) private var container
    @Environment(MenoStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var date = Date.now
    @State private var flow: Flow = .light
    @State private var note = ""
    @State private var saved = false

    var body: some View {
        let needsCheck = store.profile().bleedingNeedsCheck
        NavigationStack {
            Form {
                if needsCheck {
                    Section { SafetyBanner(title: BleedingCopy.title, message: BleedingCopy.message).listRowInsets(EdgeInsets()) }
                }
                Section {
                    DatePicker("Date", selection: $date, in: ...Date.now, displayedComponents: .date)
                    Picker("Flow", selection: $flow) {
                        ForEach(Flow.allCases, id: \.self) { Text(Copy.flow($0)).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    TextField("Note (optional)", text: $note)
                }
            }
            .menoScreen()
            .navigationTitle("Log bleeding")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let n = CycleNote(start: date, flow: flow)
                        n.note = note.isEmpty ? nil : note
                        n.isPostMenopauseFlag = needsCheck
                        store.context.insert(n)
                        store.save()
                        Task { await container.health.write(bleeding: n) }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
