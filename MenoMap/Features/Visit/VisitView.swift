import SwiftUI
import MenoCore

struct VisitView: View {
    @Environment(AppContainer.self) private var container
    @Environment(MenoStore.self) private var store
    @Environment(SubscriptionManager.self) private var subscription
    @Environment(AppRouter.self) private var router

    @State private var editing: Appointment?
    @State private var adding = false
    @State private var windowDays = 30
    @State private var pdfLanguage = Bundle.main.preferredLocalizations.first ?? "en"
    @State private var paper: RegionInfo.PaperSize = RegionInfo.paperSize(regionCode: Locale.current.region?.identifier)
    @State private var generated: GeneratedPDF?
    @State private var customQuestion = ""

    var body: some View {
        let _ = store.revision
        let appt = store.nextAppointment()
        let readiness = VisitReadinessCalculator.readiness(store: store, appointment: appt)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    appointmentCard(appt, readiness: readiness)
                    if let appt { topicsCard(appt); questionsCard(appt) }
                    notesCard(appt)
                    DisclaimerBanner(compact: true)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .menoScreen()
            .navigationTitle("Visit")
            .sheet(item: $editing) { AppointmentEditView(appointment: $0) }
            .sheet(isPresented: $adding) { AppointmentEditView(appointment: nil) }
            .sheet(item: $generated) { PDFPreviewSheet(pdf: $0) }
            .onAppear {
                paper = store.profile().paperSize
                if let lang = appt?.pdfLanguage { pdfLanguage = lang }
            }
        }
    }

    // MARK: Appointment

    @ViewBuilder private func appointmentCard(_ appt: Appointment?, readiness: VisitReadiness) -> some View {
        MenoCard {
            if let appt {
                HStack(alignment: .top, spacing: 16) {
                    ReadinessRing(value: readiness.score, lineWidth: 9).frame(width: 84, height: 84)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(AppointmentText.countdown(appt, days: DayKey.today().days(to: DayKey(appt.date))))
                            .font(MenoTheme.headline(.title3)).foregroundStyle(MenoTheme.ink)
                        Text(appt.date.formatted(date: .complete, time: .shortened)).font(.subheadline).foregroundStyle(MenoTheme.inkSecondary)
                        Button("Edit") { editing = appt }.font(.subheadline.weight(.semibold)).frame(minHeight: MenoTheme.minHit)
                    }
                }
                if readiness.gaps.isEmpty {
                    Label("Your notes are ready.", systemImage: "checkmark.seal.fill").foregroundStyle(MenoTheme.teal).font(.headline)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("To make your notes stronger").font(.headline)
                        ForEach(readiness.gaps, id: \.self) { g in
                            Label(AppointmentText.gap(g).replacingOccurrences(of: String(localized: "Next: "), with: ""), systemImage: "circle")
                                .font(.subheadline).foregroundStyle(MenoTheme.inkSecondary)
                        }
                    }
                }
            } else {
                Text("Seeing a clinician soon?").font(MenoTheme.headline(.title3))
                Text("Add the date. MenoMap shows how ready your notes are and reminds you a week before, the day before and that morning.")
                    .font(.subheadline).foregroundStyle(MenoTheme.inkSecondary)
                Button("Add appointment") { adding = true }.buttonStyle(.menoPrimary)
            }
        }
    }

    // MARK: Topics & questions

    private func topicsCard(_ appt: Appointment) -> some View {
        MenoCard {
            SectionHeader(title: "What do you want to cover?")
            FlowLayout(spacing: 8) {
                ForEach(VisitTopic.allCases, id: \.self) { t in
                    MetricChip(title: LocalizedStringKey(VisitQuestions.topic(t)), isOn: appt.topics.contains(t)) {
                        var set = appt.topics
                        if let i = set.firstIndex(of: t) { set.remove(at: i) } else { set.append(t) }
                        appt.topics = set
                        store.save()
                    }
                }
            }
        }
    }

    private func questionsCard(_ appt: Appointment) -> some View {
        let suggested = VisitQuestions.suggested(for: appt.topics)
        let custom = appt.questions.filter { $0.hasPrefix("custom:") }
        return MenoCard {
            HStack {
                SectionHeader(title: "Questions to ask")
                if !subscription.isPro { ProBadge() }
            }
            Text("Pick three or four. They print at the top of your notes.").font(.subheadline).foregroundStyle(MenoTheme.inkSecondary)
            ForEach(suggested + custom, id: \.self) { key in
                let on = appt.questions.contains(key)
                Button {
                    guard subscription.isPro else { router.present(.paywall(.appointment)); return }
                    if on { appt.questions.removeAll { $0 == key } } else { appt.questions.append(key) }
                    appt.updatedAt = .now
                    store.save()
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: on ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(on ? MenoTheme.teal : MenoTheme.inkSecondary).font(.title3)
                        Text(VisitQuestions.text(key)).foregroundStyle(MenoTheme.ink).multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                    }
                    .frame(minHeight: MenoTheme.minHit)
                }
                .buttonStyle(.plain)
            }
            if subscription.isPro {
                HStack {
                    TextField("Add your own question", text: $customQuestion)
                    Button("Add") {
                        let q = customQuestion.trimmingCharacters(in: .whitespaces)
                        guard !q.isEmpty else { return }
                        appt.questions.append("custom:" + q)
                        customQuestion = ""
                        store.save()
                    }
                    .disabled(customQuestion.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(12)
                .background(MenoTheme.ground, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: Notes (PDF)

    private func notesCard(_ appt: Appointment?) -> some View {
        MenoCard {
            SectionHeader(title: "Clinician notes")
            Text("One clean PDF: counts, heat calendar, surge clock, check-in averages, medications, patterns and your questions.")
                .font(.subheadline).foregroundStyle(MenoTheme.inkSecondary)
            Picker("Period", selection: $windowDays) {
                Text("7 days").tag(7)
                Text("30 days").tag(30)
                Text("90 days").tag(90)
            }
            .pickerStyle(.segmented)
            HStack {
                Label("Language", systemImage: "globe").foregroundStyle(MenoTheme.ink)
                Spacer()
                Picker("Language", selection: $pdfLanguage) {
                    ForEach(PDFLanguages.available, id: \.self) { code in
                        Text(PDFLanguages.name(code)).tag(code)
                    }
                }
                .labelsHidden()
                .onChange(of: pdfLanguage) { _, v in appt?.pdfLanguage = v; store.save() }
            }
            HStack {
                Label("Paper", systemImage: "doc").foregroundStyle(MenoTheme.ink)
                Spacer()
                Picker("Paper", selection: $paper) {
                    Text("A4").tag(RegionInfo.PaperSize.a4)
                    Text("US Letter").tag(RegionInfo.PaperSize.letter)
                }
                .labelsHidden()
                .onChange(of: paper) { _, v in store.profile().paperSize = v; store.save() }
            }

            Button {
                create(appt: appt)
            } label: {
                Label(subscription.canExportFullPDF ? "Create my notes" : "Preview my notes", systemImage: "doc.richtext")
            }
            .buttonStyle(.menoPrimary)
            if !subscription.isPro {
                Text(subscription.visitReportCredits > 0
                     ? String(localized: "You have \(subscription.visitReportCredits) Visit Report ready to use.")
                     : String(localized: "Free: a watermarked 7-day preview of your counts. Pro or a one-time Visit Report unlocks the full notes."))
                    .font(.caption).foregroundStyle(MenoTheme.inkSecondary)
            }
        }
    }

    private func create(appt: Appointment?) {
        let full = subscription.canExportFullPDF
        if full && !subscription.isPro {
            guard subscription.consumeVisitReportCredit() else { return }
        }
        let input = VisitPDFInput.build(store: store, appointment: appt, windowDays: full ? windowDays : 7,
                                        languageCode: pdfLanguage, paper: paper, preview: !full)
        let data = VisitPDFRenderer().makePDF(input)
        generated = GeneratedPDF(data: data, isPreview: !full, fileName: input.fileName)
    }
}

struct GeneratedPDF: Identifiable {
    let id = UUID()
    let data: Data
    let isPreview: Bool
    let fileName: String
}

enum PDFLanguages {
    /// Localizations shipped in the bundle (grows with Milestone I).
    static var available: [String] {
        let list = Bundle.main.localizations.filter { $0 != "Base" }
        return list.isEmpty ? ["en"] : list.sorted { name($0) < name($1) }
    }

    static func name(_ code: String) -> String {
        Locale(identifier: code).localizedString(forIdentifier: code)?.capitalized ?? code
    }

    static func bundle(for code: String) -> Bundle {
        if let path = Bundle.main.path(forResource: code, ofType: "lproj"), let b = Bundle(path: path) { return b }
        return .main
    }
}

// MARK: - Appointment editor

struct AppointmentEditView: View {
    let appointment: Appointment?
    @Environment(AppContainer.self) private var container
    @Environment(MenoStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var date = Calendar.current.date(byAdding: .day, value: 14, to: .now) ?? .now
    @State private var clinician = ""
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
                TextField("Clinician's name (optional)", text: $clinician)
                if let appointment {
                    Button("Delete appointment", role: .destructive) {
                        container.notifications.cancelAppointment(appointment.id)
                        store.context.delete(appointment)
                        store.save()
                        container.refreshSnapshot()
                        dismiss()
                    }
                }
            }
            .menoScreen()
            .navigationTitle(appointment == nil ? "Add appointment" : "Edit appointment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let a = appointment ?? {
                            let n = Appointment(date: date, title: String(localized: "Appointment"))
                            n.questions = VisitQuestions.general.prefix(3).map { $0 }
                            store.context.insert(n)
                            return n
                        }()
                        a.date = date
                        a.clinicianName = clinician.trimmingCharacters(in: .whitespaces).isEmpty ? nil : clinician
                        a.updatedAt = .now
                        store.save()
                        Task {
                            if await container.notifications.requestPermission() { container.notifications.scheduleAppointment(a) }
                        }
                        container.refreshSnapshot()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                guard !loaded, let a = appointment else { return }
                loaded = true
                date = a.date
                clinician = a.clinicianName ?? ""
            }
        }
    }
}
