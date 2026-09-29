import SwiftUI
import MenoCore

// MARK: - Live session

/// Full-screen surge session: timer, optional 4-4-4 breathing, then a 5-second rating.
struct SurgeSessionView: View {
    let initialKind: SurgeKind

    @Environment(SurgeController.self) private var surges
    @Environment(MenoStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var phase: Phase = .timing
    @State private var breathe = true
    @State private var intensity: Int?
    @State private var tags: Set<SurgeTag> = []
    @State private var endedSeconds = 0
    @State private var editedMinutes: Int?
    @State private var savedMessage: String?

    enum Phase { case timing, rating }

    private var kind: SurgeKind { surges.active?.kind ?? initialKind }

    private var isNightMode: Bool {
        let h = Calendar.current.component(.hour, from: .now)
        return kind == .nightSweat || h >= 21 || h < 7
    }

    private var bg: Color { isNightMode ? MenoTheme.nightGround : MenoTheme.ground }
    private var fg: Color { isNightMode ? MenoTheme.nightInk : MenoTheme.ink }
    private var fg2: Color { isNightMode ? MenoTheme.nightInk.opacity(0.7) : MenoTheme.inkSecondary }

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()
            switch phase {
            case .timing: timing
            case .rating: rating
            }
        }
        .preferredColorScheme(isNightMode ? .dark : nil)
        .onAppear {
            if !surges.isRunning { surges.start(kind: initialKind, source: .app) }
        }
        .interactiveDismissDisabled(phase == .timing)
    }

    // MARK: Timing

    private var timing: some View {
        VStack(spacing: 20) {
            HStack {
                Button { surges.cancel(); dismiss() } label: {
                    Text("Discard").font(.body).foregroundStyle(fg2).frame(minHeight: MenoTheme.minHit)
                }
                .accessibilityHint(Text("Stops the timer without saving"))
                Spacer()
                Button { dismiss() } label: {
                    Label("Minimize", systemImage: "chevron.down")
                        .labelStyle(.iconOnly).font(.title3).foregroundStyle(fg2)
                        .frame(width: MenoTheme.minHit, height: MenoTheme.minHit)
                }
                .accessibilityHint(Text("The timer keeps running on your Lock Screen"))
            }

            Picker("Type", selection: Binding(get: { kind }, set: { surges.setKind($0) })) {
                Text(Copy.kind(.hotFlash)).tag(SurgeKind.hotFlash)
                Text(Copy.kind(.nightSweat)).tag(SurgeKind.nightSweat)
            }
            .pickerStyle(.segmented)
            .frame(minHeight: MenoTheme.minHit)

            Spacer(minLength: 0)

            TimelineView(.periodic(from: .now, by: 1)) { ctx in
                let secs = surges.elapsed(now: ctx.date)
                Text(Self.clock(secs))
                    .font(.system(size: 76, weight: .semibold, design: .serif).monospacedDigit())
                    .foregroundStyle(fg)
                    .contentTransition(.numericText())
                    .accessibilityLabel(Text("Elapsed \(Copy.duration(secs))"))
            }

            if breathe {
                BreatheCoach(color: isNightMode ? MenoTheme.nightInk : MenoTheme.teal, textColor: fg, reduceMotion: reduceMotion)
                    .frame(height: 200)
                Button("Skip breathing") { withAnimation { breathe = false } }
                    .font(.subheadline).foregroundStyle(fg2).frame(minHeight: MenoTheme.minHit)
            } else {
                Button("Breathe with me") { withAnimation { breathe = true } }
                    .font(.subheadline.weight(.semibold)).foregroundStyle(fg).frame(minHeight: MenoTheme.minHit)
            }

            Text("These often crest and ease within a couple of minutes. This is not medical treatment.")
                .font(.callout)
                .foregroundStyle(fg2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            Button {
                endedSeconds = surges.elapsed()
                withAnimation(.easeInOut(duration: 0.25)) { phase = .rating }
            } label: {
                Text("It's easing. End it.")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(isNightMode ? MenoTheme.nightGround : MenoTheme.onTeal)
                    .frame(maxWidth: .infinity, minHeight: 64)
                    .background(isNightMode ? MenoTheme.nightInk.opacity(0.85) : MenoTheme.teal,
                                in: RoundedRectangle(cornerRadius: MenoTheme.radiusButton, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
    }

    // MARK: Rating

    private var rating: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("How strong was it?")
                        .font(MenoTheme.headline(.title))
                        .foregroundStyle(fg)
                    Text("\(Copy.kind(kind)) · \(Copy.duration(editedMinutes.map { $0 * 60 } ?? endedSeconds))")
                        .font(.body).foregroundStyle(fg2)
                }
                IntensityPicker(value: $intensity, night: isNightMode)
                DurationEditor(seconds: endedSeconds, minutes: $editedMinutes, tint: fg)
                VStack(alignment: .leading, spacing: 10) {
                    Text("Anything going on? (optional)").font(.headline).foregroundStyle(fg)
                    TagPicker(selection: $tags)
                }
                Button {
                    let secs = editedMinutes.map { $0 * 60 } ?? endedSeconds
                    surges.finish(intensity: intensity, tags: Array(tags).sorted { $0.rawValue < $1.rawValue }, durationOverride: secs)
                    dismiss()
                } label: {
                    Text(intensity == nil ? "Save without rating" : "Save")
                }
                .buttonStyle(.menoPrimary)
                .padding(.top, 8)
            }
            .padding(24)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    static func clock(_ secs: Int) -> String {
        String(format: "%d:%02d", secs / 60, secs % 60)
    }
}

/// Box-style 4-4-4 breathing (in 4, hold 4, out 4). Reduce Motion: text countdown only.
struct BreatheCoach: View {
    var color: Color
    var textColor: Color
    var reduceMotion: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 1 : 1.0 / 30)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 12)
            let (label, progress): (String, Double) = {
                switch t {
                case ..<4: (String(localized: "Breathe in"), t / 4)
                case ..<8: (String(localized: "Hold"), 1)
                default: (String(localized: "Breathe out"), 1 - (t - 8) / 4)
                }
            }()
            let count = 4 - Int(t.truncatingRemainder(dividingBy: 4))
            ZStack {
                if !reduceMotion {
                    Circle()
                        .fill(color.opacity(0.14))
                        .scaleEffect(0.55 + 0.45 * progress)
                    Circle()
                        .strokeBorder(color.opacity(0.5), lineWidth: 2)
                        .scaleEffect(0.55 + 0.45 * progress)
                }
                VStack(spacing: 4) {
                    Text(label).font(.title3.weight(.semibold)).foregroundStyle(textColor)
                    Text("\(count)").font(.system(.title, design: .serif).monospacedDigit()).foregroundStyle(textColor.opacity(0.8))
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text(label))
        }
    }
}

// MARK: - Shared pickers

struct IntensityPicker: View {
    @Binding var value: Int?
    var night = false

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...5, id: \.self) { i in
                let on = value == i
                Button {
                    value = on ? nil : i
                    UISelectionFeedbackGenerator().selectionChanged()
                } label: {
                    VStack(spacing: 4) {
                        Text("\(i)").font(.system(.title2, design: .serif).weight(.semibold).monospacedDigit())
                        Text(Copy.intensityWord(i)).font(.caption2.weight(.medium)).lineLimit(2).minimumScaleFactor(0.7)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, minHeight: 72)
                    .foregroundStyle(on ? (i >= 4 ? Color.white : MenoTheme.ink) : (night ? MenoTheme.nightInk : MenoTheme.ink))
                    .background(on ? MenoTheme.heat(i) : (night ? Color.white.opacity(0.06) : MenoTheme.surface),
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(on ? MenoTheme.ember : MenoTheme.hairline, lineWidth: on ? 2 : 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("\(i), \(Copy.intensityWord(i))"))
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }
}

struct TagPicker: View {
    @Binding var selection: Set<SurgeTag>

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(SurgeTag.allCases, id: \.self) { t in
                MetricChip(title: LocalizedStringKey(Copy.tag(t)), systemImage: Copy.tagSymbol(t), isOn: selection.contains(t)) {
                    if selection.contains(t) { selection.remove(t) } else { selection.insert(t) }
                }
            }
        }
    }
}

struct DurationEditor: View {
    let seconds: Int
    @Binding var minutes: Int?
    var tint: Color = MenoTheme.ink

    var body: some View {
        HStack {
            Label("Length", systemImage: "timer").foregroundStyle(tint)
            Spacer()
            if let m = minutes {
                Stepper(value: Binding(get: { m }, set: { minutes = max(1, min($0, 120)) }), in: 1...120) {
                    Text("\(m) min").monospacedDigit().foregroundStyle(tint)
                }
                .fixedSize()
            } else {
                Text(Copy.duration(seconds)).monospacedDigit().foregroundStyle(tint)
                Button("Edit") { minutes = max(1, Int((Double(seconds) / 60).rounded())) }
                    .font(.body.weight(.semibold)).frame(minHeight: MenoTheme.minHit)
            }
        }
        .padding(14)
        .background(MenoTheme.surface.opacity(0.6), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - After the fact

struct AfterTheFactView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss

    @State private var kind: SurgeKind = {
        let h = Calendar.current.component(.hour, from: .now)
        return (h >= 21 || h < 9) ? .nightSweat : .hotFlash
    }()
    @State private var when = Date.now.addingTimeInterval(-15 * 60)
    @State private var bucket: DurationBucket = .oneToFive
    @State private var intensity: Int?
    @State private var tags: Set<SurgeTag> = []

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $kind) {
                        Text(Copy.kind(.hotFlash)).tag(SurgeKind.hotFlash)
                        Text(Copy.kind(.nightSweat)).tag(SurgeKind.nightSweat)
                    }
                    .pickerStyle(.segmented)
                    DatePicker("When", selection: $when, in: ...Date.now)
                }
                Section("How long") {
                    Picker("How long", selection: $bucket) {
                        Text("Under 1 min").tag(DurationBucket.underOne)
                        Text("1–5 min").tag(DurationBucket.oneToFive)
                        Text("5–15 min").tag(DurationBucket.fiveToFifteen)
                        Text("15+ min").tag(DurationBucket.overFifteen)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                Section("How strong") {
                    IntensityPicker(value: $intensity)
                        .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
                }
                Section("Anything going on?") {
                    TagPicker(selection: $tags)
                        .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
                }
            }
            .menoScreen()
            .navigationTitle("Log a past surge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        container.log(SurgeRecord(kind: kind, startedAt: when, durationSec: bucket.representativeSeconds,
                                                  intensity: intensity, tags: Array(tags), source: .afterTheFact))
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Rate later

struct RateSurgeView: View {
    let surgeID: UUID
    @Environment(AppContainer.self) private var container
    @Environment(MenoStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var intensity: Int?
    @State private var tags: Set<SurgeTag> = []
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            Group {
                if let event = store.surge(id: surgeID) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            Text("\(Copy.kind(event.kind)) at \(event.startedAt.formatted(date: .omitted, time: .shortened))")
                                .font(MenoTheme.headline(.title2))
                            Text(Copy.duration(event.durationSec)).foregroundStyle(MenoTheme.inkSecondary)
                            IntensityPicker(value: $intensity)
                            TagPicker(selection: $tags)
                            Button("Save") {
                                var r = event.record
                                r.intensity = intensity
                                r.tags = Array(tags)
                                container.update(event, with: r)
                                dismiss()
                            }
                            .buttonStyle(.menoPrimary)
                            Button("Delete this surge", role: .destructive) { confirmDelete = true }
                                .frame(maxWidth: .infinity, minHeight: MenoTheme.minHit)
                                .confirmationDialog("Delete this surge?", isPresented: $confirmDelete, titleVisibility: .visible) {
                                    Button("Delete", role: .destructive) { container.delete(event); dismiss() }
                                }
                        }
                        .padding(24)
                    }
                    .onAppear {
                        intensity = event.intensity
                        tags = Set(event.record.tags)
                    }
                } else {
                    EmptyState(systemImage: "checkmark.circle", title: "Already saved", message: "This surge isn't here anymore.")
                }
            }
            .menoScreen()
            .navigationTitle("Rate surge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
    }
}
