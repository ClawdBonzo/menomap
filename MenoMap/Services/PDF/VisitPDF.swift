import SwiftUI
import PDFKit
import ObjectiveC
import MenoCore

protocol PDFExporting {
    func makePDF(_ input: VisitPDFInput) -> Data
}

/// Everything the notes need, snapshotted from the store (main actor) before rendering.
struct VisitPDFInput {
    var window: DayWindow
    var stats: SurgeStats
    var checkInAverages: [(TrackedMetric, Double, Int)]
    var checkInDays: Int
    var medications: [MedicationRecord]
    var medDetails: [UUID: (dose: String, route: String, schedule: String)]
    var doseTaken: Int
    var doseSkipped: Int
    var insights: [Insight]
    var bleedingNotes: [(Date, Flow, Bool)]
    var bleedingFromHealth: Int
    var healthSymptoms: [(String, Int)]
    var palpitationsLogged: Bool
    var sleepAvgMinutes: Double?
    var sleepNights: Int
    var questions: [String]
    var clinicianName: String?
    var appointmentDate: Date?
    var stage: MenopauseStage?
    var languageCode: String
    var paper: RegionInfo.PaperSize
    var preview: Bool
    var regionCode: String?

    var fileName: String {
        "MenoMap-notes-\(window.end)\(preview ? "-preview" : "").pdf"
    }

    @MainActor
    static func build(store: MenoStore, appointment: Appointment?, windowDays: Int, languageCode: String,
                      paper: RegionInfo.PaperSize, preview: Bool) -> VisitPDFInput {
        let window = DayWindow(lastDays: windowDays, endingOn: .today())
        let checkIns = store.checkInRecords(in: window)
        let stats = StatsCalculator.compute(window: window, surges: store.surgeRecords(in: window), checkIns: checkIns)
        let avgs = StatsCalculator.checkInAverages(window: window, checkIns: checkIns)
            .map { ($0.key, $0.value.avg, $0.value.n) }
            .sorted { TrackedMetric.allCases.firstIndex(of: $0.0) ?? 0 < TrackedMetric.allCases.firstIndex(of: $1.0) ?? 0 }
        let meds = store.medications()
        let doses = store.doses().filter { window.contains(DayKey($0.takenAt)) }
        let insights = InsightEngine().compute(store.insightInput(), today: .today())
            .filter { $0.windowDays <= max(windowDays * 2, 28) || windowDays >= 30 }
        let from = window.start.startDate()
        let bleeding = store.cycleNotes().filter { $0.start >= from }.map { ($0.start, $0.flow, $0.isPostMenopauseFlag) }
        let symptoms = store.healthSymptoms().filter { $0.date >= from }
        let grouped = Dictionary(grouping: symptoms.filter { !$0.typeRaw.contains("BleedingAfterMenopause") && $0.typeRaw != HealthSymptomType.cycleStart }, by: \.typeRaw)
            .map { (HealthSymptomNames.name($0.key), Set($0.value.map { DayKey($0.date) }).count) }
            .sorted { $0.1 > $1.1 }
        let nights = store.healthNights().filter { n in DayKey(string: n.morningKey).map(window.contains) ?? false }.compactMap(\.minutesAsleep)
        return VisitPDFInput(
            window: window, stats: stats, checkInAverages: avgs, checkInDays: checkIns.count,
            medications: meds.map(\.record),
            medDetails: Dictionary(uniqueKeysWithValues: meds.map { ($0.id, ($0.doseText, $0.route, $0.scheduleText)) }),
            doseTaken: doses.filter { !$0.skipped }.count, doseSkipped: doses.filter(\.skipped).count,
            insights: Array(insights.prefix(3)),
            bleedingNotes: bleeding,
            bleedingFromHealth: symptoms.filter { $0.typeRaw.contains("BleedingAfterMenopause") }.count,
            healthSymptoms: grouped,
            palpitationsLogged: symptoms.contains { $0.typeRaw.contains("RapidPounding") },
            sleepAvgMinutes: nights.isEmpty ? nil : Double(nights.reduce(0, +)) / Double(nights.count),
            sleepNights: nights.count,
            questions: appointment?.questions ?? [],
            clinicianName: appointment?.clinicianName,
            appointmentDate: appointment?.date,
            stage: store.profile().stage,
            languageCode: languageCode, paper: paper, preview: preview,
            regionCode: Locale.current.region?.identifier)
    }
}

enum HealthSymptomNames {
    static func name(_ raw: String) -> String {
        switch raw {
        case let r where r.contains("SleepChanges"): String(localized: "Sleep changes")
        case let r where r.contains("MoodChanges"): String(localized: "Mood changes")
        case let r where r.contains("MemoryLapse"): String(localized: "Memory lapse")
        case let r where r.contains("Fatigue"): String(localized: "Fatigue")
        case let r where r.contains("RapidPounding"): String(localized: "Rapid, pounding or fluttering heartbeat")
        case let r where r.contains("VaginalDryness"): String(localized: "Vaginal dryness")
        case let r where r.contains("BladderIncontinence"): String(localized: "Bladder incontinence")
        case let r where r.contains("Headache"): String(localized: "Headache")
        case let r where r.contains("Chills"): String(localized: "Chills")
        default: raw
        }
    }
}

// MARK: - Renderer

struct VisitPDFRenderer: PDFExporting {
    @MainActor
    func makePDF(_ input: VisitPDFInput) -> Data {
        LocalizationOverride.with(input.languageCode) {
            let size = CGSize(width: input.paper.size.width, height: input.paper.size.height)
            let locale = Locale(identifier: input.languageCode)
            let pages: [AnyView] = input.preview
                ? [AnyView(PreviewPage(input: input))]
                : [AnyView(NotesPage1(input: input)), AnyView(NotesPage2(input: input))]
            let data = NSMutableData()
            var box = CGRect(origin: .zero, size: size)
            let info: [CFString: Any] = [kCGPDFContextTitle: "MenoMap notes", kCGPDFContextCreator: "MenoMap"]
            guard let consumer = CGDataConsumer(data: data as CFMutableData),
                  let ctx = CGContext(consumer: consumer, mediaBox: &box, info as CFDictionary) else { return Data() }
            for (i, page) in pages.enumerated() {
                let view = PDFPageFrame(pageNumber: i + 1, pageCount: pages.count, size: size, preview: input.preview) { page }
                    .environment(\.locale, locale)
                    .environment(\.colorScheme, .light)
                let r = ImageRenderer(content: view)
                r.proposedSize = ProposedViewSize(size)
                r.render { _, draw in
                    ctx.beginPDFPage(nil)
                    draw(ctx)
                    ctx.endPDFPage()
                }
            }
            ctx.closePDF()
            return data as Data
        }
    }
}

// MARK: - Page chrome

private enum P {
    static let ink = Color(hex: 0x1E2524)
    static let ink2 = Color(hex: 0x5E6663)
    static let hair = Color(hex: 0x1E2524, opacity: 0.12)
    static let ember = Color(hex: 0xD4552A)
    static let teal = Color(hex: 0x0D6B66)
    static let danger = Color(hex: 0xB3261E)
    static func heat(_ l: Int) -> Color { l == 0 ? hair : ember.opacity(MenoTheme.heatOpacity[min(max(l, 0), 5)]) }
}

private struct PDFPageFrame<Content: View>: View {
    let pageNumber: Int
    let pageCount: Int
    let size: CGSize
    let preview: Bool
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            Color.white
            VStack(alignment: .leading, spacing: 0) {
                content
                Spacer(minLength: 0)
                Rectangle().fill(P.hair).frame(height: 0.5).padding(.bottom, 6)
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Entered by the user. Not a diagnosis. Not a complete medical record.")
                            .font(.system(size: 7.5, weight: .semibold)).foregroundStyle(P.ink)
                        Text("Made with MenoMap · gwlabs.app/menomap").font(.system(size: 7)).foregroundStyle(P.ink2)
                    }
                    Spacer()
                    Text("\(pageNumber) / \(pageCount)").font(.system(size: 7)).foregroundStyle(P.ink2)
                    if pageNumber == 1, let qr = QRCode.image(for: LegalLinks.clinicians.absoluteString) {
                        Image(uiImage: qr).interpolation(.none).resizable().frame(width: 34, height: 34).padding(.leading, 8)
                    }
                }
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 34)
            if preview {
                Text("PREVIEW")
                    .font(.system(size: 110, weight: .black, design: .serif))
                    .foregroundStyle(P.ember.opacity(0.10))
                    .rotationEffect(.degrees(-35))
            }
        }
        .frame(width: size.width, height: size.height)
    }
}

private struct PDFSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(Copy.caps(title)).font(.system(size: 8, weight: .bold)).tracking(1).foregroundStyle(P.teal)
            content
        }
        .padding(.top, 10)
    }
}

private struct Header: View {
    let input: VisitPDFInput

    var body: some View {
        let locale = Locale(identifier: input.languageCode)
        let range = "\(input.window.start.startDate().formatted(.dateTime.day().month(.abbreviated).year().locale(locale))) – \(input.window.end.startDate().formatted(.dateTime.day().month(.abbreviated).year().locale(locale)))"
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text("Symptom notes").font(.system(size: 22, weight: .semibold, design: .serif)).foregroundStyle(P.ink)
                Spacer()
                Text("MenoMap").font(.system(size: 11, weight: .semibold, design: .serif)).foregroundStyle(P.ink2)
            }
            Text("\(input.window.count) days · \(range)").font(.system(size: 9.5)).foregroundStyle(P.ink2)
            HStack(spacing: 12) {
                if let who = input.clinicianName { Text("For \(who)").font(.system(size: 9.5, weight: .semibold)) }
                if let d = input.appointmentDate {
                    Text("Appointment \(d.formatted(.dateTime.day().month(.abbreviated).year().locale(locale)))").font(.system(size: 9.5))
                }
                if let s = input.stage, s != .preferNotToSay { Text("Stage (self-reported): \(Copy.stage(s))").font(.system(size: 9.5)) }
                Spacer()
                Text("Generated \(Date.now.formatted(.dateTime.day().month(.abbreviated).year().locale(locale)))").font(.system(size: 8.5)).foregroundStyle(P.ink2)
            }
            .foregroundStyle(P.ink)
            Text(Disclaimer.full)
                .font(.system(size: 7.5)).foregroundStyle(P.ink2)
                .padding(7)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(P.hair))
                .padding(.top, 4)
        }
    }
}

private struct Metric: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value).font(.system(size: 17, weight: .semibold, design: .serif)).foregroundStyle(P.ink)
            Text(label).font(.system(size: 7.5)).foregroundStyle(P.ink2).lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Pages

private struct NotesPage1: View {
    let input: VisitPDFInput

    var body: some View {
        let s = input.stats
        let f = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(1))
        VStack(alignment: .leading, spacing: 0) {
            Header(input: input)

            if !input.questions.isEmpty {
                PDFSection(title: String(localized: "Questions I'd like to ask")) {
                    ForEach(Array(input.questions.prefix(6).enumerated()), id: \.offset) { i, q in
                        Text("\(i + 1). \(VisitQuestions.text(q))").font(.system(size: 10, weight: .medium)).foregroundStyle(P.ink)
                    }
                }
            }

            PDFSection(title: String(localized: "Surges (hot flashes and night sweats)")) {
                HStack(alignment: .top) {
                    Metric(value: "\(s.total)", label: String(localized: "surges logged"))
                    Metric(value: s.perDayAverage.formatted(f), label: String(localized: "per logged day"))
                    Metric(value: "\(s.hotFlashes) / \(s.nightSweats)", label: String(localized: "hot flashes / night sweats"))
                    Metric(value: s.avgIntensity.map { "\($0.formatted(f)) / 5" } ?? "–", label: String(localized: "average strength (\(s.rated) rated)"))
                    Metric(value: s.avgDurationSec.map(Copy.duration) ?? "–", label: String(localized: "typical length"))
                    Metric(value: s.total == 0 ? "–" : "\(Int((Double(s.nightSurges) / Double(s.total) * 100).rounded()))%", label: String(localized: "between 9pm and 7am"))
                }
                Text("Logged on \(s.loggedDays) of \(input.window.count) days. Strength is self-rated from 1 (mild) to 5 (intense).")
                    .font(.system(size: 7.5)).foregroundStyle(P.ink2)
            }

            HStack(alignment: .top, spacing: 20) {
                PDFSection(title: String(localized: "Heat calendar")) {
                    PDFHeatGrid(days: s.days)
                    HStack(spacing: 3) {
                        Text("0").font(.system(size: 7)).foregroundStyle(P.ink2)
                        ForEach(0...5, id: \.self) { l in Rectangle().fill(P.heat(l)).frame(width: 9, height: 9) }
                        Text("Surges × strength per day").font(.system(size: 7)).foregroundStyle(P.ink2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                PDFSection(title: String(localized: "Time of day")) {
                    SurgeClock(histogram: s.hourHistogram).frame(width: 130, height: 130)
                    if let p = s.peakTime {
                        Text("Most often around \(Copy.clock(p))").font(.system(size: 8.5)).foregroundStyle(P.ink)
                    }
                }
                .frame(width: 150, alignment: .leading)
            }

            if !input.checkInAverages.isEmpty {
                PDFSection(title: String(localized: "Evening check-ins (0–10, \(input.checkInDays) days)")) {
                    HStack(alignment: .top) {
                        ForEach(input.checkInAverages, id: \.0) { m, avg, n in
                            Metric(value: avg.formatted(f), label: "\(Copy.metricShort(m)) · \(Copy.metricAnchors(m).high.lowercased()) = 10 · n=\(n)")
                        }
                    }
                }
            }

            if let sleep = input.sleepAvgMinutes {
                PDFSection(title: String(localized: "Sleep from Apple Health")) {
                    Text("Average \(InsightCopy.hoursMinutes(sleep)) asleep over \(input.sleepNights) nights (from Apple Health).")
                        .font(.system(size: 9.5)).foregroundStyle(P.ink)
                }
            }
        }
    }
}

private struct NotesPage2: View {
    let input: VisitPDFInput

    var body: some View {
        let locale = Locale(identifier: input.languageCode)
        VStack(alignment: .leading, spacing: 0) {
            Text("Symptom notes, continued").font(.system(size: 14, weight: .semibold, design: .serif)).foregroundStyle(P.ink)

            PDFSection(title: String(localized: "Medications (entered by the user)")) {
                if input.medications.isEmpty {
                    Text("None entered.").font(.system(size: 9.5)).foregroundStyle(P.ink2)
                }
                ForEach(input.medications.prefix(10), id: \.id) { m in
                    let d = input.medDetails[m.id]
                    VStack(alignment: .leading, spacing: 1) {
                        Text(m.name).font(.system(size: 10, weight: .semibold)).foregroundStyle(P.ink)
                        Text([Copy.medCategory(m.category), d?.dose ?? "", d?.route ?? "", d?.schedule ?? "",
                              String(localized: "since \(m.startDate.formatted(.dateTime.day().month(.abbreviated).year().locale(locale)))"),
                              m.endDate.map { String(localized: "stopped \($0.formatted(.dateTime.day().month(.abbreviated).year().locale(locale)))") } ?? ""]
                            .filter { !$0.isEmpty }.joined(separator: " · "))
                            .font(.system(size: 8.5)).foregroundStyle(P.ink2)
                    }
                }
                if input.doseTaken + input.doseSkipped > 0 {
                    Text("Doses marked in this period: \(input.doseTaken) taken, \(input.doseSkipped) skipped.")
                        .font(.system(size: 8.5)).foregroundStyle(P.ink2)
                }
            }

            if !input.insights.isEmpty {
                PDFSection(title: String(localized: "Patterns in the entries")) {
                    ForEach(input.insights) { i in
                        let t = InsightCopy.text(i)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(t.title).font(.system(size: 9.5, weight: .semibold)).foregroundStyle(P.ink)
                            Text(t.body).font(.system(size: 8.5)).foregroundStyle(P.ink)
                        }
                        .padding(.bottom, 3)
                    }
                    Text("Patterns compare the user's own entries. They are coincidence checks, not causes.")
                        .font(.system(size: 7.5)).foregroundStyle(P.ink2)
                }
            }

            if !input.bleedingNotes.isEmpty || input.bleedingFromHealth > 0 {
                PDFSection(title: String(localized: "Bleeding")) {
                    ForEach(Array(input.bleedingNotes.prefix(8).enumerated()), id: \.offset) { _, n in
                        Text("\(n.0.formatted(.dateTime.day().month(.abbreviated).year().locale(locale))) · \(Copy.flow(n.1))\(n.2 ? " · " + String(localized: "logged after menopause") : "")")
                            .font(.system(size: 9.5)).foregroundStyle(P.ink)
                    }
                    if input.bleedingFromHealth > 0 {
                        Text("Bleeding after menopause recorded in Apple Health: \(input.bleedingFromHealth) times.")
                            .font(.system(size: 9.5)).foregroundStyle(P.ink)
                    }
                    if input.bleedingNotes.contains(where: \.2) || input.bleedingFromHealth > 0 {
                        Text(BleedingCopy.message)
                            .font(.system(size: 9, weight: .semibold)).foregroundStyle(P.danger)
                            .padding(6).overlay(RoundedRectangle(cornerRadius: 4).stroke(P.danger.opacity(0.5)))
                    }
                }
            }

            if !input.healthSymptoms.isEmpty {
                PDFSection(title: String(localized: "Other symptoms recorded in Apple Health")) {
                    ForEach(input.healthSymptoms.prefix(8), id: \.0) { name, days in
                        Text("\(name): \(days) days").font(.system(size: 9.5)).foregroundStyle(P.ink)
                    }
                    if input.palpitationsLogged {
                        Text(SafetyCopy.palpitations).font(.system(size: 8.5)).foregroundStyle(P.ink2)
                    }
                }
            }

            PDFSection(title: String(localized: "About these notes")) {
                Text("These notes summarize what the user entered in MenoMap and, where labeled, data they chose to bring in from Apple Health. MenoMap does not diagnose, prescribe or give treatment advice.")
                    .font(.system(size: 8.5)).foregroundStyle(P.ink2)
            }
        }
    }
}

/// Free: watermarked 7-day counts only.
private struct PreviewPage: View {
    let input: VisitPDFInput

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Header(input: input)
            PDFSection(title: String(localized: "Surges (hot flashes and night sweats)")) {
                HStack {
                    Metric(value: "\(input.stats.total)", label: String(localized: "surges logged"))
                    Metric(value: "\(input.stats.hotFlashes)", label: String(localized: "hot flashes"))
                    Metric(value: "\(input.stats.nightSweats)", label: String(localized: "night sweats"))
                }
            }
            PDFSection(title: String(localized: "Full notes include")) {
                ForEach([String(localized: "30 or 90 days of history and the heat calendar"),
                         String(localized: "Time-of-day chart and check-in averages"),
                         String(localized: "Medications, patterns and your questions")], id: \.self) {
                    Text("· \($0)").font(.system(size: 10)).foregroundStyle(P.ink2)
                }
            }
        }
    }
}

private struct PDFHeatGrid: View {
    let days: [DayHeat]

    var body: some View {
        let cols = min(days.count, days.count <= 7 ? 7 : days.count <= 31 ? 10 : 15)
        let grid = Array(repeating: GridItem(.fixed(days.count > 31 ? 16 : 22), spacing: 3), count: max(cols, 1))
        LazyVGrid(columns: grid, alignment: .leading, spacing: 3) {
            ForEach(days, id: \.day) { d in
                Rectangle().fill(P.heat(d.level))
                    .frame(height: days.count > 31 ? 16 : 22)
                    .overlay {
                        if d.count > 0 {
                            Text("\(d.count)").font(.system(size: 7, weight: .semibold)).foregroundStyle(d.level >= 4 ? .white : P.ink)
                        }
                    }
            }
        }
    }
}

enum SafetyCopy {
    static var palpitations: String {
        String(localized: "Heart sensations have many causes. If they are new, severe, or come with chest pain, shortness of breath, or fainting, seek care now.")
    }

    static var emergency: String {
        if let n = RegionInfo.emergencyNumber(regionCode: Locale.current.region?.identifier) {
            return String(localized: "This can be an emergency. Call \(n). MenoMap cannot assess this.")
        }
        return String(localized: "This can be an emergency. Contact your local emergency number. MenoMap cannot assess this.")
    }
}

// MARK: - Preview & share

struct PDFPreviewSheet: View {
    let pdf: GeneratedPDF
    @Environment(\.dismiss) private var dismiss
    @Environment(AppRouter.self) private var router
    @State private var url: URL?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                PDFKitView(data: pdf.data)
                VStack(spacing: 10) {
                    if pdf.isPreview {
                        Button("Unlock full notes") {
                            dismiss()
                            Task { @MainActor in
                                try? await Task.sleep(for: .milliseconds(400))
                                router.present(.paywall(.pdf))
                            }
                        }
                        .buttonStyle(.menoPrimary)
                    } else if let url {
                        ShareLink(item: url) { Label("Share, print or save", systemImage: "square.and.arrow.up") }
                            .buttonStyle(.menoPrimary)
                    }
                }
                .padding(16)
                .background(MenoTheme.ground)
            }
            .navigationTitle(pdf.isPreview ? "Preview" : "Your notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .task {
                let u = FileManager.default.temporaryDirectory.appending(path: pdf.fileName)
                try? pdf.data.write(to: u, options: [.atomic, .completeFileProtection])
                url = u
            }
            .onDisappear { if !pdf.isPreview { ReviewPrompt.recordPositiveMoment() } }
        }
    }
}

struct PDFKitView: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> PDFView {
        let v = PDFView()
        v.autoScales = true
        v.backgroundColor = UIColor(MenoTheme.ground)
        v.document = PDFDocument(data: data)
        return v
    }

    func updateUIView(_ uiView: PDFView, context: Context) {}
}

// MARK: - Localization override (PDF language picker)

/// Swaps Bundle.main's string lookup to another .lproj while a PDF renders synchronously on the main thread.
private final class OverrideBundle: Bundle, @unchecked Sendable {
    nonisolated(unsafe) static var override: Bundle?

    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        if let b = Self.override { return b.localizedString(forKey: key, value: value, table: tableName) }
        return super.localizedString(forKey: key, value: value, table: tableName)
    }
}

enum LocalizationOverride {
    private static var installed = false

    @MainActor
    static func with<T>(_ languageCode: String, _ body: () -> T) -> T {
        let current = Bundle.main.preferredLocalizations.first ?? "en"
        guard languageCode != current else { return body() }
        if !installed {
            object_setClass(Bundle.main, OverrideBundle.self)
            installed = true
        }
        OverrideBundle.override = PDFLanguages.bundle(for: languageCode)
        defer { OverrideBundle.override = nil }
        return body()
    }
}
