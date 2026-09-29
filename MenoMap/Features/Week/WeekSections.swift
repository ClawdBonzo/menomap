import SwiftUI
import MenoCore

// MARK: - Patterns

struct PatternsSection: View {
    let insights: [Insight]
    @Environment(SubscriptionManager.self) private var subscription
    @Environment(AppRouter.self) private var router
    @Environment(MenoStore.self) private var store
    @AppStorage("meno.reveal.id") private var revealedID = ""
    @AppStorage("meno.reveal.day") private var revealedDay = ""

    private var canRevealFree: Bool {
        guard let d = DayKey(string: revealedDay) else { return true }
        return d.days(to: .today()) >= 7
    }

    var body: some View {
        let list = insights.filter { $0.ruleID != InsightRuleID.experimentResult }
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Patterns")
            if list.isEmpty {
                MenoCard {
                    EmptyState(systemImage: "sparkle.magnifyingglass", title: "Patterns are still forming",
                               message: "They need about two weeks of check-ins and surges. They always compare your own entries, never other people's.")
                }
            }
            let firstLockedID = list.first { !(subscription.isPro || !$0.isPremium || $0.id == revealedID) }?.id
            ForEach(list) { i in
                let t = InsightCopy.text(i)
                let open = subscription.isPro || !i.isPremium || i.id == revealedID
                MenoCard {
                    Label(t.title, systemImage: t.symbol).font(.headline).foregroundStyle(MenoTheme.ink)
                    if open {
                        Text(t.body).font(.body).foregroundStyle(MenoTheme.ink).fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text(t.body).font(.body).foregroundStyle(MenoTheme.ink).blur(radius: 6).accessibilityHidden(true)
                            .fixedSize(horizontal: false, vertical: true)
                        if i.id != firstLockedID {
                            Button { router.present(.paywall(.pattern)) } label: {
                                Label("Unlock with Pro", systemImage: "lock.fill").font(.subheadline.weight(.semibold))
                            }
                            .frame(minHeight: MenoTheme.minHit)
                        } else {
                        HStack {
                            if canRevealFree {
                                Button("Reveal one free this week") {
                                    revealedID = i.id
                                    revealedDay = DayKey.today().description
                                }
                                .buttonStyle(.menoQuiet)
                            }
                            Button("Unlock all") { router.present(.paywall(.pattern)) }.buttonStyle(.menoSecondary)
                        }
                        }
                    }
                }
            }
            if !list.isEmpty {
                Text("Your entries, compared with your entries. Coincidence checks, not causes.")
                    .font(.caption).foregroundStyle(MenoTheme.inkSecondary)
            }
        }
    }
}

// MARK: - Experiments

struct ExperimentsSection: View {
    @Environment(AppContainer.self) private var container
    @Environment(MenoStore.self) private var store
    @Environment(SubscriptionManager.self) private var subscription
    @Environment(AppRouter.self) private var router
    @State private var picking = false
    @State private var sharing: Insight?

    var body: some View {
        let active = store.activeExperiment()
        let results = InsightEngine().experimentResults(store.insightInput(), today: .today())
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Experiments")
            if let a = active?.record {
                MenoCard {
                    Label(Copy.experiment(a.kind, custom: a.customTitle), systemImage: "flask").font(.headline)
                    let day = a.startDay.days(to: .today()) + 1
                    ProgressView(value: Double(min(day, a.lengthDays)), total: Double(a.lengthDays)).tint(MenoTheme.teal)
                    Text("Day \(min(day, a.lengthDays)) of \(a.lengthDays). Keep logging as usual; MenoMap compares with the \(a.lengthDays) days before.")
                        .font(.subheadline).foregroundStyle(MenoTheme.inkSecondary)
                    Button("Stop this experiment", role: .destructive) {
                        active?.abandoned = true
                        store.save()
                        if let id = active?.id { container.notifications.cancelExperiment(id) }
                    }
                    .font(.subheadline)
                    .frame(minHeight: MenoTheme.minHit)
                }
            } else {
                MenoCard {
                    Text("Try one change for two weeks and see what your own entries show.")
                        .font(.body).foregroundStyle(MenoTheme.ink)
                    Button {
                        if subscription.isPro { picking = true } else { router.present(.paywall(.experiment)) }
                    } label: {
                        HStack { Text("Start an experiment"); if !subscription.isPro { ProBadge() } }
                    }
                    .buttonStyle(.menoQuiet)
                }
            }
            ForEach(results) { r in
                let t = InsightCopy.text(r)
                MenoCard {
                    Label(t.title, systemImage: "flask.fill").font(.headline)
                    if subscription.isPro {
                        Text(t.body).font(.body).fixedSize(horizontal: false, vertical: true)
                        Button { sharing = r } label: { Label("Share result", systemImage: "square.and.arrow.up") }
                            .buttonStyle(.menoSecondary)
                    } else {
                        Text("Results are ready.").foregroundStyle(MenoTheme.inkSecondary)
                        Button("See results") { router.present(.paywall(.experiment)) }.buttonStyle(.menoQuiet)
                    }
                }
            }
        }
        .sheet(isPresented: $picking) { ExperimentPicker() }
        .sheet(item: $sharing) { r in ShareCardSheet(kind: .experiment(r)) }
    }
}

struct ExperimentPicker: View {
    @Environment(AppContainer.self) private var container
    @Environment(MenoStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var custom = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(ExperimentKind.allCases.filter { $0 != .custom }, id: \.self) { k in
                        Button { start(k) } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(Copy.experiment(k)).font(.headline).foregroundStyle(MenoTheme.ink)
                                Text(Copy.experimentHow(k)).font(.subheadline).foregroundStyle(MenoTheme.inkSecondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                } footer: {
                    Text("Results compare your own entries before and during. They're a coincidence check, not proof.")
                }
                Section("Your own") {
                    TextField("e.g. cotton pajamas", text: $custom)
                    Button("Start") { start(.custom) }.disabled(custom.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .menoScreen()
            .navigationTitle("Two-week experiment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }

    private func start(_ k: ExperimentKind) {
        let e = Experiment(kind: k, startDay: .today(), customTitle: k == .custom ? custom : nil)
        store.context.insert(e)
        store.save()
        Task {
            if await container.notifications.requestPermission() { container.notifications.scheduleExperimentDone(e.record) }
        }
        dismiss()
    }
}

// MARK: - Heat Report entry

struct HeatReportEntry: View {
    var body: some View {
        NavigationLink { HeatReportView() } label: {
            HStack(spacing: 14) {
                Image(systemName: "calendar.badge.clock").font(.title2).foregroundStyle(MenoTheme.ember)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Heat Report").font(MenoTheme.headline(.headline)).foregroundStyle(MenoTheme.ink)
                    Text("Last month, in one page").font(.subheadline).foregroundStyle(MenoTheme.inkSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(MenoTheme.inkSecondary)
            }
            .padding(16)
            .background(MenoTheme.surface, in: RoundedRectangle(cornerRadius: MenoTheme.radiusCard, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: MenoTheme.radiusCard, style: .continuous).strokeBorder(MenoTheme.hairline))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Recent entries (timeline)

struct RecentEntriesSection: View {
    @Environment(MenoStore.self) private var store
    @Environment(AppRouter.self) private var router

    enum Entry: Identifiable {
        case surge(SurgeEvent), medStart(Medication), checkIn(CheckInRecord)
        var id: String {
            switch self {
            case .surge(let e): "s\(e.id)"
            case .medStart(let m): "m\(m.id)"
            case .checkIn(let c): "c\(c.id)"
            }
        }
        var date: Date {
            switch self {
            case .surge(let e): e.startedAt
            case .medStart(let m): m.startDate
            case .checkIn(let c): c.day.startDate().addingTimeInterval(20 * 3600)
            }
        }
    }

    var body: some View {
        let window = DayWindow(lastDays: 14, endingOn: .today())
        let entries: [Entry] = (store.surgeEvents(in: window).map(Entry.surge)
            + store.medications().filter { window.contains(DayKey($0.startDate)) }.map(Entry.medStart)
            + store.checkInRecords(in: window).map(Entry.checkIn))
            .sorted { $0.date > $1.date }
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Timeline")
            MenoCard(padding: 4) {
                if entries.isEmpty {
                    Text("Nothing logged in the last two weeks.").foregroundStyle(MenoTheme.inkSecondary).padding(12)
                }
                ForEach(entries.prefix(30)) { entry in
                    row(entry)
                    if entry.id != entries.prefix(30).last?.id { Divider().padding(.leading, 52) }
                }
            }
        }
    }

    @ViewBuilder private func row(_ entry: Entry) -> some View {
        switch entry {
        case .surge(let e):
            Button { router.present(.rate(e.id)) } label: {
                HStack(spacing: 12) {
                    Circle().fill(MenoTheme.heat(e.intensity ?? 2)).frame(width: 28, height: 28)
                        .overlay { Text(e.intensity.map { "\($0)" } ?? "?").font(.caption.weight(.bold)).foregroundStyle(MenoTheme.onHeat(e.intensity ?? 2)) }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(Copy.kind(e.kind)).font(.subheadline.weight(.semibold)).foregroundStyle(MenoTheme.ink)
                        Text("\(e.startedAt.formatted(.dateTime.weekday(.abbreviated).hour().minute())) · \(Copy.duration(e.durationSec))\(e.record.tags.isEmpty ? "" : " · " + e.record.tags.map(Copy.tag).joined(separator: ", "))")
                            .font(.caption).foregroundStyle(MenoTheme.inkSecondary).lineLimit(1)
                    }
                    Spacer()
                    if e.sourceRaw == SurgeSource.healthImport.rawValue {
                        Image(systemName: "heart.fill").font(.caption).foregroundStyle(MenoTheme.inkSecondary)
                            .accessibilityLabel(Text("From Apple Health"))
                    } else if e.sourceRaw == SurgeSource.watch.rawValue {
                        Image(systemName: "applewatch").font(.caption).foregroundStyle(MenoTheme.inkSecondary)
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        case .medStart(let m):
            HStack(spacing: 12) {
                Image(systemName: "pills.fill").foregroundStyle(MenoTheme.teal).frame(width: 28)
                Text("Started \(m.name)").font(.subheadline.weight(.semibold))
                Spacer()
                Text(m.startDate.formatted(.dateTime.day().month(.abbreviated))).font(.caption).foregroundStyle(MenoTheme.inkSecondary)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
        case .checkIn(let c):
            HStack(spacing: 12) {
                Image(systemName: "square.and.pencil").foregroundStyle(MenoTheme.teal).frame(width: 28)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Check-in").font(.subheadline.weight(.semibold))
                    Text(c.scores.sorted { $0.key.rawValue < $1.key.rawValue }.map { "\(Copy.metricShort($0.key)) \($0.value)" }.joined(separator: " · "))
                        .font(.caption).foregroundStyle(MenoTheme.inkSecondary).lineLimit(1)
                }
                Spacer()
                Text(Copy.date(c.day)).font(.caption).foregroundStyle(MenoTheme.inkSecondary)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
        }
    }
}
