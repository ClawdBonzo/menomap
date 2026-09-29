import SwiftUI
import MenoCore

struct PrivacyView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss

    @State private var exportURL: URL?
    @State private var step = 0 // two-step delete: 0 idle, 1 first confirm, 2 final confirm
    @State private var deleted = false

    var body: some View {
        List {
            Section("What MenoMap stores") {
                row("iphone", "On this iPhone only",
                    "Surges, check-ins, medications, cycle notes, appointments and experiments live in the app's own storage on this device. They are included in your normal encrypted iPhone backup.")
                row("heart", "Apple Health",
                    "If you connect Health, MenoMap reads the types you allowed and writes only the surges and bleeding you log here. Apple Health manages that data, not us.")
                row("person.crop.circle.badge.xmark", "No account, no cloud",
                    "There's no sign-in. MenoMap never uploads your health data, and nothing is stored in iCloud by the app.")
                row("chart.bar.xaxis", "No health analytics",
                    "We don't track what you log. Purchases are counted anonymously to measure the App Store and Apple Ads.")
                row("square.and.arrow.up", "Only what you share",
                    "Share cards and PDFs are made on your iPhone and leave it only if you send them.")
            }

            Section {
                Button {
                    exportURL = try? DataExporter.export(store: container.store)
                } label: { Label("Export all my data (JSON)", systemImage: "square.and.arrow.down") }
                if let exportURL {
                    ShareLink(item: exportURL) { Label("Share the export file", systemImage: "square.and.arrow.up") }
                }
            } footer: {
                Text("A readable file of everything you've logged. Free, always.")
            }

            Section {
                Button(role: .destructive) { step = 1 } label: { Label("Delete all data", systemImage: "trash") }
            } footer: {
                Text("Deletes everything MenoMap stores on this iPhone. Data in Apple Health stays until you remove it in the Health app.")
            }

            if deleted {
                Section { Label("All MenoMap data was deleted.", systemImage: "checkmark.circle").foregroundStyle(MenoTheme.teal) }
            }
        }
        .menoScreen()
        .navigationTitle("Privacy")
        .confirmationDialog("Delete all MenoMap data?", isPresented: Binding(get: { step == 1 }, set: { if !$0 && step == 1 { step = 0 } }),
                            titleVisibility: .visible) {
            Button("Continue", role: .destructive) { step = 2 }
            Button("Cancel", role: .cancel) { step = 0 }
        } message: {
            Text("Surges, check-ins, medications, notes and appointments will be removed from this iPhone.")
        }
        .alert("This can't be undone", isPresented: Binding(get: { step == 2 }, set: { if !$0 { step = 0 } })) {
            Button("Delete everything", role: .destructive) {
                container.deleteAllData()
                step = 0
                deleted = true
            }
            Button("Keep my data", role: .cancel) { step = 0 }
        } message: {
            Text("Export first if you might want it later.")
        }
    }

    private func row(_ symbol: String, _ title: LocalizedStringKey, _ body: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol).foregroundStyle(MenoTheme.teal).frame(width: 26)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(body).font(.subheadline).foregroundStyle(MenoTheme.inkSecondary)
            }
        }
        .padding(.vertical, 4)
    }
}

/// JSON export of everything the user logged (Free, always).
enum DataExporter {
    struct Export: Encodable {
        var exportedAt = Date.now
        var app = "MenoMap"
        var surges: [SurgeRecord]
        var checkIns: [CheckInRecord]
        var medications: [Med]
        var doses: [DoseRecord]
        var cycle: [Cycle]
        var appointments: [Appt]
        var experiments: [ExperimentRecord]

        struct Med: Encodable { var id: UUID; var name, category, dose, route, schedule, notes: String; var startDate: Date; var endDate: Date? }
        struct Cycle: Encodable { var date: Date; var flow: String; var note: String?; var flaggedAfterMenopause: Bool }
        struct Appt: Encodable { var date: Date; var clinician: String?; var topics: [String]; var questions: [String] }
    }

    @MainActor
    static func export(store: MenoStore) throws -> URL {
        let e = Export(
            surges: store.surgeRecords(),
            checkIns: store.checkInRecords(),
            medications: store.medications().map {
                .init(id: $0.id, name: $0.name, category: $0.categoryRaw, dose: $0.doseText, route: $0.route,
                      schedule: $0.scheduleText, notes: $0.notes, startDate: $0.startDate, endDate: $0.endDate)
            },
            doses: store.doses().map(\.record),
            cycle: store.cycleNotes().map { .init(date: $0.start, flow: $0.flowRaw, note: $0.note, flaggedAfterMenopause: $0.isPostMenopauseFlag) },
            appointments: store.appointments().map { .init(date: $0.date, clinician: $0.clinicianName, topics: $0.topicsRaw, questions: $0.questions) },
            experiments: store.experiments().map(\.record))
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        let url = FileManager.default.temporaryDirectory.appending(path: "MenoMap-export-\(DayKey.today()).json")
        try enc.encode(e).write(to: url, options: [.atomic, .completeFileProtection])
        return url
    }
}

/// Pre-written heads-up messages sent through the share sheet (never iCloud; Guideline 5.1.3(ii)).
struct TellMyPersonView: View {
    @AppStorage("meno.tell.custom") private var custom = ""

    private var templates: [String] {
        [
            String(localized: "Night sweat. Cracking the window."),
            String(localized: "Hot flash, give me 3 minutes."),
            String(localized: "Rough night. I'll be slow this morning."),
            String(localized: "Could you turn the fan on?"),
            String(localized: "Heads up: running hot today. Not you, it's me."),
        ]
    }

    var body: some View {
        List {
            Section {
                ForEach(templates, id: \.self) { t in
                    ShareLink(item: t) {
                        HStack {
                            Text(t).foregroundStyle(MenoTheme.ink)
                            Spacer()
                            Image(systemName: "paperplane").foregroundStyle(MenoTheme.teal)
                        }
                    }
                }
            } footer: {
                Text("Opens Messages or any app you choose. MenoMap doesn't send anything by itself.")
            }
            Section("Your own") {
                TextField("Write your own heads-up", text: $custom)
                if !custom.isEmpty {
                    ShareLink(item: custom) { Label("Send", systemImage: "paperplane") }
                }
            }
        }
        .menoScreen()
        .navigationTitle("Tell my person")
    }
}
