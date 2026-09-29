import SwiftUI
import MenoCore

/// Onboarding (Docs/SPEC_ADDITIONS §10). Every step can be skipped except privacy/legal. No paywall.
struct OnboardingView: View {
    @Environment(AppContainer.self) private var container
    @Environment(MenoStore.self) private var store

    enum Step: Int, CaseIterable {
        case promise, why, health, metrics, stage, appointment, privacy, surgeSetup, first
    }

    @State private var step: Step = DebugArgs.value("-MMOnboardingStep").flatMap { name in Step.allCases.first { "\($0)" == name } } ?? .promise
    @State private var why: Set<String> = []
    @State private var metrics: Set<TrackedMetric> = [.hotFlashes, .nightSweats, .sleep]
    @State private var remind = false
    @State private var remindTime = Calendar.current.date(from: DateComponents(hour: 20, minute: 30)) ?? .now
    @State private var stage: MenopauseStage?
    @State private var healthConnected = false
    @State private var importing = false
    @State private var imported = 0
    @State private var hasAppointment = false
    @State private var apptDate = Calendar.current.date(byAdding: .day, value: 14, to: .now) ?? .now
    @State private var clinician = ""

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    content
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
                .id(step)
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
            }
            .scrollBounceBehavior(.basedOnSize)
            bottomBar
        }
        .background(MenoTheme.ground.ignoresSafeArea())
        .tint(MenoTheme.teal)
    }

    // MARK: Chrome

    private var topBar: some View {
        HStack {
            if step != .promise {
                Button { go(Step(rawValue: step.rawValue - 1) ?? .promise) } label: {
                    Image(systemName: "chevron.left").font(.title3).frame(width: MenoTheme.minHit, height: MenoTheme.minHit)
                }
                .accessibilityLabel(Text("Back"))
            } else {
                Color.clear.frame(width: MenoTheme.minHit, height: MenoTheme.minHit)
            }
            Spacer()
            HStack(spacing: 6) {
                ForEach(Step.allCases, id: \.self) { s in
                    Capsule().fill(s.rawValue <= step.rawValue ? MenoTheme.teal : MenoTheme.hairline)
                        .frame(width: s == step ? 18 : 6, height: 6)
                }
            }
            .accessibilityElement()
            .accessibilityLabel(Text("Step \(step.rawValue + 1) of \(Step.allCases.count)"))
            Spacer()
            if step != .privacy && step != .promise && step != .first {
                Button("Skip") { advance() }.frame(minWidth: MenoTheme.minHit, minHeight: MenoTheme.minHit)
            } else {
                Color.clear.frame(width: MenoTheme.minHit, height: MenoTheme.minHit)
            }
        }
        .padding(.horizontal, 12)
        .foregroundStyle(MenoTheme.inkSecondary)
    }

    @ViewBuilder private var bottomBar: some View {
        if step != .first && step != .surgeSetup {
            Button(primaryTitle) { primaryAction() }
                .buttonStyle(.menoPrimary)
                .disabled(importing)
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
        }
    }

    private var primaryTitle: LocalizedStringKey {
        switch step {
        case .promise: "Get started"
        case .health: healthConnected ? "Continue" : "Connect Apple Health"
        case .privacy: "I understand"
        default: "Continue"
        }
    }

    private func go(_ s: Step) {
        withAnimation(.easeInOut(duration: 0.25)) { step = s }
    }

    private func advance() {
        commit(step)
        var next = Step(rawValue: step.rawValue + 1) ?? .first
        // Stage came from Apple Health (iOS 27): skip asking.
        if next == .stage, store.profile().stageSource == "health" { next = .appointment }
        go(next)
    }

    private func primaryAction() {
        if step == .health && !healthConnected {
            Task { await connectHealth() }
        } else {
            advance()
        }
    }

    // MARK: Commit per step

    private func commit(_ s: Step) {
        let p = store.profile()
        switch s {
        case .why: p.whyHereRaw = Array(why)
        case .metrics:
            var ordered = TrackedMetric.allCases.filter { metrics.contains($0) }
            if ordered.isEmpty { ordered = [.sleep] }
            p.trackedMetrics = ordered
            if remind {
                let c = Calendar.current.dateComponents([.hour, .minute], from: remindTime)
                p.reminderHour = c.hour
                p.reminderMinute = c.minute ?? 0
                Task {
                    if await container.notifications.requestPermission() {
                        container.notifications.scheduleEveningCheckIn(hour: c.hour ?? 20, minute: c.minute ?? 30)
                    }
                }
            }
        case .stage:
            if let stage {
                p.stage = stage
                p.stageSource = "user"
                if stage == .postmenopause || stage == .menopause { p.noLongerHasPeriods = true }
            }
        case .appointment:
            if hasAppointment {
                let a = Appointment(date: apptDate, title: String(localized: "Appointment"))
                a.clinicianName = clinician.trimmingCharacters(in: .whitespaces).isEmpty ? nil : clinician
                store.context.insert(a)
                container.notifications.scheduleAppointment(a)
            }
        default: break
        }
        p.updatedAt = .now
        store.save()
    }

    private func connectHealth() async {
        importing = true
        defer { importing = false }
        guard await container.health.requestAuthorization() else {
            advance()
            return
        }
        healthConnected = true
        imported = await container.health.importRecent(days: 90)
        await container.health.refreshStage()
        await container.health.refreshNights(days: 90)
        store.profile().healthImportDone = true
        store.save()
        container.refreshSnapshot()
    }

    private func finish(then sheet: AppSheet?) {
        let p = store.profile()
        p.onboardingDone = true
        p.hasSeenSurgeSetup = true
        store.save()
        container.health.startIfAuthorized()
        container.refreshSnapshot()
        if let sheet {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(350))
                container.router.present(sheet)
            }
        }
    }

    // MARK: Content

    @ViewBuilder private var content: some View {
        switch step {
        case .promise:
            OnboardingHero()
            Text("See what's changing.")
                .font(MenoTheme.headline(.largeTitle)).foregroundStyle(MenoTheme.ink)
            Text("Log a surge in one tap. Spot patterns. Walk into your appointment with notes.")
                .font(.title3).foregroundStyle(MenoTheme.inkSecondary)
            VStack(alignment: .leading, spacing: 14) {
                promiseRow("hand.tap", "One tap from your Lock Screen, Control Center or Watch")
                promiseRow("square.grid.3x3.middle.filled", "A heat map of your own weather")
                promiseRow("doc.text", "Clean notes for your clinician")
                promiseRow("lock", "Your health data never leaves your iPhone")
            }
            .padding(.top, 8)

        case .why:
            title("Why are you here?", "Pick any that fit. It shapes what you see first.")
            FlowLayout(spacing: 8) {
                ForEach(whyOptions, id: \.0) { key, label in
                    MetricChip(title: label, isOn: why.contains(key)) {
                        if why.contains(key) { why.remove(key) } else { why.insert(key) }
                    }
                }
            }

        case .health:
            title("Bring in what you've already logged",
                  "If you've logged symptoms in Apple Health, MenoMap can show them on day one. Surges you log here are saved back to Health.")
            VStack(alignment: .leading, spacing: 12) {
                healthRow("arrow.down.circle", "Reads", "Hot flashes, night sweats, sleep, other symptoms, menopause stage and wrist temperature")
                healthRow("arrow.up.circle", "Writes", "Only the surges and bleeding you log in MenoMap")
                healthRow("iphone", "Stays on your iPhone", "Nothing is sent to us. Ever.")
            }
            if importing {
                HStack { ProgressView(); Text("Reading your last 90 days…").foregroundStyle(MenoTheme.inkSecondary) }
            } else if healthConnected {
                Label(imported > 0 ? String(localized: "Found \(imported) surges from the last 90 days") : String(localized: "Connected. Nothing to import yet."),
                      systemImage: "checkmark.circle.fill")
                    .font(.headline).foregroundStyle(MenoTheme.teal)
            }

        case .metrics:
            title("What should Today show?", "Hot flashes, night sweats and sleep are on. Add more if they matter to you. You can change this any time.")
            FlowLayout(spacing: 8) {
                ForEach(TrackedMetric.allCases, id: \.self) { m in
                    MetricChip(title: LocalizedStringKey(Copy.metricShort(m)), systemImage: Copy.metricSymbol(m), isOn: metrics.contains(m)) {
                        if metrics.contains(m) { metrics.remove(m) } else { metrics.insert(m) }
                    }
                }
            }
            Toggle(isOn: $remind.animation()) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Remind me to check in").font(.headline)
                    Text("One gentle evening reminder. Off by default.").font(.subheadline).foregroundStyle(MenoTheme.inkSecondary)
                }
            }
            .padding(.top, 8)
            if remind {
                DatePicker("Time", selection: $remindTime, displayedComponents: .hourAndMinute)
            }

        case .stage:
            title("Where are you? (optional)", "It only changes which notes you see. MenoMap never tries to decide this for you.")
            VStack(spacing: 10) {
                ForEach(MenopauseStage.allCases, id: \.self) { s in
                    Button { stage = s } label: {
                        HStack {
                            Text(Copy.stage(s)).font(.body.weight(.semibold))
                            Spacer()
                            if stage == s { Image(systemName: "checkmark.circle.fill") }
                        }
                        .foregroundStyle(stage == s ? MenoTheme.teal : MenoTheme.ink)
                        .padding(16)
                        .frame(minHeight: 52)
                        .background(MenoTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(stage == s ? MenoTheme.teal : MenoTheme.hairline))
                    }
                    .buttonStyle(.plain)
                }
            }
            if stage == .postmenopause || stage == .menopause {
                SafetyBanner(title: BleedingCopy.title,
                             message: String(localized: "Any bleeding after menopause should be checked by a clinician."))
            }

        case .appointment:
            title("Seeing a clinician soon?", "Add the date and MenoMap will get your notes ready in time. Optional.")
            Toggle("I have an appointment", isOn: $hasAppointment.animation()).font(.headline)
            if hasAppointment {
                DatePicker("Date", selection: $apptDate, in: Date.now..., displayedComponents: [.date, .hourAndMinute])
                TextField("Clinician's name (optional)", text: $clinician)
                    .padding(14).frame(minHeight: 52)
                    .background(MenoTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(MenoTheme.hairline))
            }

        case .privacy:
            title("Private by design", nil)
            VStack(alignment: .leading, spacing: 12) {
                healthRow("iphone", "Everything stays on this iPhone", "No account. No cloud. No analytics on your health.")
                healthRow("square.and.arrow.up", "You decide what leaves", "Only what you share or print yourself.")
                healthRow("trash", "Delete any time", "You → Privacy → Delete all.")
            }
            DisclaimerBanner()
            Text("By continuing you agree that MenoMap processes the health information you enter on this device to show your logs, patterns and notes.")
                .font(.footnote).foregroundStyle(MenoTheme.inkSecondary)
            HStack(spacing: 16) {
                Link("Privacy Policy", destination: LegalLinks.privacy)
                Link("Terms of Use", destination: LegalLinks.terms)
            }
            .font(.footnote.weight(.semibold))

        case .surgeSetup:
            SurgeSetupView(isOnboarding: true) { advance() }

        case .first:
            if imported > 0 {
                title("Here's your last 90 days", "Brought in from Apple Health.")
                let window = DayWindow(lastDays: 35, endingOn: .today())
                HeatCalendar(days: StatsCalculator.compute(window: window, surges: store.surgeRecords(in: window), checkIns: []).days)
                HeatLegend()
            } else {
                title("You're set.", "Start with whatever's happening now.")
            }
            VStack(spacing: 12) {
                Button { finish(then: .surge(.hotFlash)) } label: {
                    Label("I'm having a surge now", systemImage: "flame.fill")
                }
                .buttonStyle(.menoPrimary)
                Button { finish(then: .checkIn) } label: {
                    Label("Do my first check-in", systemImage: "square.and.pencil")
                }
                .buttonStyle(.menoSecondary)
                Button("Just look around") { finish(then: nil) }
                    .frame(minHeight: MenoTheme.minHit)
                    .foregroundStyle(MenoTheme.inkSecondary)
            }
            .padding(.top, 8)
        }
    }

    private var whyOptions: [(String, LocalizedStringKey)] {
        [("changes", "Noticing changes"), ("symptoms", "Tracking symptoms"), ("peri", "Perimenopause"),
         ("menopause", "Menopause"), ("post", "Post-menopause"), ("treatment", "Tracking treatment"),
         ("visit", "Preparing for a visit"), ("unsure", "Not sure yet")]
    }

    private func title(_ t: LocalizedStringKey, _ sub: LocalizedStringKey?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(t).font(MenoTheme.headline(.largeTitle)).foregroundStyle(MenoTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
            if let sub {
                Text(sub).font(.body).foregroundStyle(MenoTheme.inkSecondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func promiseRow(_ symbol: String, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol).font(.title3).foregroundStyle(MenoTheme.teal).frame(width: 28)
            Text(text).font(.body).foregroundStyle(MenoTheme.ink)
        }
    }

    private func healthRow(_ symbol: String, _ head: LocalizedStringKey, _ body: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol).font(.title3).foregroundStyle(MenoTheme.teal).frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(head).font(.headline).foregroundStyle(MenoTheme.ink)
                Text(body).font(.subheadline).foregroundStyle(MenoTheme.inkSecondary)
            }
        }
    }
}

/// Contour rings: the brand mark, drawn live (ember heat, teal calm at the core).
struct OnboardingHero: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        ZStack {
            ForEach(0..<6, id: \.self) { i in
                let s = 1 - CGFloat(i) * 0.15
                ContourShape(seed: i)
                    .stroke(i == 5 ? MenoTheme.teal : MenoTheme.ember.opacity(0.25 + Double(i) * 0.12), lineWidth: i == 5 ? 3 : 2)
                    .scaleEffect(s * (pulse ? 1.02 : 1))
            }
        }
        .frame(height: 180)
        .frame(maxWidth: .infinity)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) { pulse = true }
        }
        .accessibilityHidden(true)
    }
}

/// A slightly irregular closed loop, like a topographic contour.
struct ContourShape: Shape {
    var seed: Int

    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        var p = Path()
        let steps = 96
        for k in 0...steps {
            let a = Double(k) / Double(steps) * 2 * .pi
            let wobble = 1 + 0.06 * sin(3 * a + Double(seed)) + 0.04 * sin(5 * a - Double(seed) * 0.7)
            let pt = CGPoint(x: c.x + CGFloat(cos(a) * wobble) * r * 1.25, y: c.y + CGFloat(sin(a) * wobble) * r * 0.95)
            if k == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}

enum LegalLinks {
    // Pages published on gwlabs.app before submission (Docs/SPEC_ADDITIONS §15).
    static let home = URL(string: "https://gwlabs.app/menomap") ?? URL(fileURLWithPath: "/")
    static let privacy = URL(string: "https://gwlabs.app/menomap/privacy") ?? home
    static let terms = URL(string: "https://gwlabs.app/menomap/terms") ?? home
    static let clinicians = URL(string: "https://gwlabs.app/menomap/clinicians") ?? home
    static let appStore = home
}
