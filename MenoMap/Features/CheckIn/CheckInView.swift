import SwiftUI
import MenoCore

/// Evening check-in: only the enabled metrics, nothing required, Done always enabled. Target: under 30 seconds.
struct CheckInView: View {
    @Environment(AppContainer.self) private var container
    @Environment(MenoStore.self) private var store
    @Environment(SubscriptionManager.self) private var subscription
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss

    var day: DayKey = .today()

    @State private var scores: [TrackedMetric: Int] = [:]
    @State private var alcohol: Bool?
    @State private var lateCaffeine: Bool?
    @State private var note = ""
    @State private var loaded = false

    private var metrics: [TrackedMetric] { store.profile().trackedMetrics }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text(day == .today() ? "How was today?" : "How was \(Copy.date(day))?")
                        .font(MenoTheme.headline(.title))
                        .foregroundStyle(MenoTheme.ink)
                    Text("Skip anything. Nothing here is required.")
                        .font(.subheadline).foregroundStyle(MenoTheme.inkSecondary)

                    ForEach(metrics, id: \.self) { m in
                        ScoreRow(metric: m, value: Binding(get: { scores[m] }, set: { scores[m] = $0 }))
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        YesNoRow(title: "Alcohol today?", systemImage: "wineglass", value: $alcohol)
                        YesNoRow(title: "Caffeine later than usual?", systemImage: "cup.and.saucer", value: $lateCaffeine)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("One line for future you (optional)").font(.headline)
                        TextField("e.g. hot office, new sheets", text: $note)
                            .textFieldStyle(.plain)
                            .padding(14)
                            .frame(minHeight: 52)
                            .background(MenoTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(MenoTheme.hairline))
                    }

                    Button("Done", action: save)
                        .buttonStyle(.menoPrimary)
                        .padding(.top, 4)
                }
                .padding(20)
            }
            .menoScreen()
            .navigationTitle("Check-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Done", action: save).fontWeight(.semibold) }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        if let existing = store.checkIn(for: day)?.record {
            scores = existing.scores
            alcohol = existing.alcohol
            lateCaffeine = existing.lateCaffeine
            note = existing.note ?? ""
        }
    }

    private func save() {
        let isNew = store.checkIn(for: day) == nil
        store.upsertCheckIn(CheckInRecord(day: day, scores: scores, alcohol: alcohol, lateCaffeine: lateCaffeine, note: note))
        let profile = store.profile()
        if isNew { profile.checkInCount += 1 }
        store.save()
        container.refreshSnapshot()
        container.notifications.scheduleThirtyDayNudgeIfNeeded(
            loggedDays: store.loggedDays(in: DayWindow(lastDays: 60, endingOn: .today())).count)
        dismiss()
        // The evening check-in is the natural bedtime moment: arm Night Watch if the user turned it on.
        if profile.nightWatchOn, Clock.hour >= 19 { container.nightWatch.arm() }
        // Paywall after the third check-in (never in session 1: onboarding can't reach three).
        if isNew, profile.checkInCount == 3, !subscription.isPro {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(600))
                router.present(.paywall(.checkIns))
            }
        }
    }
}

/// A 0–10 score as 11 large segments you can tap or drag across. VoiceOver: adjustable.
struct ScoreRow: View {
    let metric: TrackedMetric
    @Binding var value: Int?

    var body: some View {
        let anchors = Copy.metricAnchors(metric)
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(Copy.metric(metric), systemImage: Copy.metricSymbol(metric))
                    .font(.headline)
                    .foregroundStyle(MenoTheme.ink)
                Spacer()
                Text(value.map { "\($0)" } ?? "–")
                    .font(MenoTheme.number(.title2))
                    .foregroundStyle(value == nil ? MenoTheme.inkSecondary : MenoTheme.ink)
                    .frame(minWidth: 36, alignment: .trailing)
            }
            ScoreBar(value: $value, higherIsBetter: metric.higherIsBetter)
                .accessibilityElement()
                .accessibilityLabel(Text(Copy.metric(metric)))
                .accessibilityValue(Text(value.map { "\($0) of 10" } ?? String(localized: "Not answered")))
                .accessibilityAdjustableAction { dir in
                    switch dir {
                    case .increment: value = min((value ?? -1) + 1, 10)
                    case .decrement: value = max((value ?? 1) - 1, 0)
                    @unknown default: break
                    }
                }
            HStack {
                Text("0 · \(anchors.low)")
                Spacer()
                Text("\(anchors.high) · 10")
            }
            .font(.caption)
            .foregroundStyle(MenoTheme.inkSecondary)
        }
        .padding(16)
        .background(MenoTheme.surface, in: RoundedRectangle(cornerRadius: MenoTheme.radiusCard, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: MenoTheme.radiusCard, style: .continuous).strokeBorder(MenoTheme.hairline))
    }
}

struct ScoreBar: View {
    @Binding var value: Int?
    var higherIsBetter: Bool

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let seg = (w - 10 * 3) / 11
            HStack(spacing: 3) {
                ForEach(0...10, id: \.self) { i in
                    let on = value.map { i <= $0 } ?? false
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(on ? MenoTheme.teal.opacity(0.35 + 0.065 * Double(i)) : MenoTheme.hairline)
                        .frame(width: seg)
                        .overlay {
                            if value == i {
                                RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(MenoTheme.teal, lineWidth: 2)
                            }
                        }
                }
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { g in
                let i = Int((g.location.x / max(w, 1)) * 11)
                let v = min(max(i, 0), 10)
                if v != value {
                    value = v
                    UISelectionFeedbackGenerator().selectionChanged()
                }
            })
        }
        .frame(height: 44)
    }
}

struct YesNoRow: View {
    let title: LocalizedStringKey
    let systemImage: String
    @Binding var value: Bool?

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                Label(title, systemImage: systemImage).font(.body).foregroundStyle(MenoTheme.ink)
                Spacer(minLength: 8)
                chips
            }
            VStack(alignment: .leading, spacing: 8) {
                Label(title, systemImage: systemImage).font(.body).foregroundStyle(MenoTheme.ink)
                HStack(spacing: 10) { chips }
            }
        }
    }

    @ViewBuilder private var chips: some View {
        MetricChip(title: "Yes", isOn: value == true) { value = value == true ? nil : true }
        MetricChip(title: "No", isOn: value == false) { value = value == false ? nil : false }
    }
}
