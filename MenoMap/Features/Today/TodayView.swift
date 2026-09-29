import SwiftUI
import MenoCore

struct TodayView: View {
    @Environment(AppContainer.self) private var container
    @Environment(MenoStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(SurgeController.self) private var surges
    @Environment(SubscriptionManager.self) private var subscription

    var body: some View {
        let _ = store.revision
        let profile = store.profile()
        let today = DayKey.today()
        let week = StatsCalculator.compute(window: DayWindow(lastDays: 7, endingOn: today),
                                           surges: store.surgeRecords(in: DayWindow(lastDays: 7, endingOn: today)),
                                           checkIns: store.checkInRecords(in: DayWindow(lastDays: 7, endingOn: today)))
        let insights = InsightEngine().compute(store.insightInput(), today: today).filter { $0.ruleID != InsightRuleID.experimentResult }

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header(profile)
                    if let active = surges.active {
                        ActiveSurgeBanner(active: active) { router.present(.surge(active.kind)) }
                    }
                    SurgeHero()
                    if let unrated = store.unratedSurges().first, Date.now.timeIntervalSince(unrated.startedAt) < 3 * 86400 {
                        RateLaterCard(event: unrated) { router.present(.rate(unrated.id)) }
                    }
                    MorningCard()
                    BleedingReminderCard()
                    CheckInCard(day: today)
                    AppointmentCard()
                    MenoCard {
                        SectionHeader(title: "Last 7 days", trailing: "See more") { router.tab = .week }
                        HeatStrip(days: week.days)
                        HStack {
                            HeatLegend()
                            Spacer()
                            Label("Sleep score", systemImage: "circle.fill")
                                .font(.caption2).foregroundStyle(MenoTheme.teal)
                                .labelStyle(.titleAndIcon).imageScale(.small)
                        }
                        Text(Copy.weekHeadline(count: week.total, voice: profile.voice))
                            .font(MenoTheme.headline(.headline))
                            .foregroundStyle(MenoTheme.ink)
                    }
                    PatternSlot(insights: insights)
                    ExperimentCard()
                    QuickActions()
                    DisclaimerBanner(compact: true)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .menoScreen()
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) {
                Rectangle().fill(.clear).frame(height: 0).background(MenoTheme.ground.opacity(0.94).ignoresSafeArea(edges: .top))
            }
        }
    }

    private func header(_ profile: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)).uppercased())
                .font(.caption.weight(.semibold))
                .tracking(1.2)
                .foregroundStyle(MenoTheme.inkSecondary)
            Text(greeting(profile.firstName))
                .font(MenoTheme.headline(.largeTitle))
                .foregroundStyle(MenoTheme.ink)
        }
        .padding(.top, 12)
        .accessibilityElement(children: .combine)
    }

    private func greeting(_ name: String?) -> String {
        let h = Calendar.current.component(.hour, from: .now)
        let n = name.flatMap { $0.isEmpty ? nil : $0 }
        switch h {
        case 5..<12: return n.map { String(localized: "Good morning, \($0)") } ?? String(localized: "Good morning")
        case 12..<18: return n.map { String(localized: "Good afternoon, \($0)") } ?? String(localized: "Good afternoon")
        default: return n.map { String(localized: "Good evening, \($0)") } ?? String(localized: "Good evening")
        }
    }
}

// MARK: - Surge hero

struct SurgeHero: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.dynamicTypeSize) private var dynamicType

    private var nightNow: Bool {
        let h = Calendar.current.component(.hour, from: .now)
        return h >= 21 || h < 7
    }

    var body: some View {
        let primary: SurgeKind = nightNow ? .nightSweat : .hotFlash
        let secondary: SurgeKind = nightNow ? .hotFlash : .nightSweat
        VStack(spacing: 10) {
            Button {
                router.present(.surge(primary))
            } label: {
                HStack(spacing: 14) {
                    if !dynamicType.isAccessibilitySize {
                        Image(systemName: primary == .nightSweat ? "moon.haze.fill" : "flame.fill")
                            .font(.system(size: 30, weight: .semibold))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(primary == .nightSweat ? "I'm having a night sweat" : "I'm having a surge")
                            .font(.system(.title, design: .serif).weight(.semibold))
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Start timing. Breathe if you want.")
                            .font(.subheadline)
                            .opacity(0.85)
                    }
                    Spacer(minLength: 0)
                }
                .foregroundStyle(MenoTheme.onTeal)
                .padding(.horizontal, 22)
                .padding(.vertical, 18)
                .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
                .background(
                    LinearGradient(colors: [MenoTheme.teal, MenoTheme.teal.opacity(0.86)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: MenoTheme.teal.opacity(0.35), radius: 18, y: 8)
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text("Starts a timer and a Lock Screen Live Activity"))

            AdaptiveStack(spacing: 10) {
                Button { router.present(.surge(secondary)) } label: {
                    Label(Copy.kind(secondary), systemImage: secondary == .nightSweat ? "moon.haze" : "flame")
                }
                .buttonStyle(.menoQuiet)
                Button { router.present(.afterTheFact) } label: {
                    Label("Already over", systemImage: "clock.arrow.circlepath")
                }
                .buttonStyle(.menoQuiet)
            }
        }
    }
}

struct ActiveSurgeBanner: View {
    let active: MenoSnapshot.ActiveSurge
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "timer").foregroundStyle(MenoTheme.ember)
                Text("\(Copy.kind(active.kind)) running")
                    .font(.headline).foregroundStyle(MenoTheme.ink)
                Spacer()
                Text(active.startedAt, style: .timer)
                    .font(.system(.headline, design: .serif).monospacedDigit())
                    .foregroundStyle(MenoTheme.ink)
                Image(systemName: "chevron.right").foregroundStyle(MenoTheme.inkSecondary)
            }
            .padding(16)
            .background(MenoTheme.ember.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct RateLaterCard: View {
    let event: SurgeEvent
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "hand.tap").font(.title3).foregroundStyle(MenoTheme.teal)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Rate your \(event.startedAt.formatted(date: .omitted, time: .shortened)) \(Copy.kind(event.kind).lowercased())")
                        .font(.headline).foregroundStyle(MenoTheme.ink)
                    Text("One tap: how strong was it?").font(.subheadline).foregroundStyle(MenoTheme.inkSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(MenoTheme.inkSecondary)
            }
            .padding(16)
            .background(MenoTheme.tealSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Check-in card

struct CheckInCard: View {
    let day: DayKey
    @Environment(MenoStore.self) private var store
    @Environment(AppRouter.self) private var router

    var body: some View {
        let done = store.checkIn(for: day) != nil
        Button { router.present(.checkIn) } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(done ? MenoTheme.teal : MenoTheme.tealSoft).frame(width: 44, height: 44)
                    Image(systemName: done ? "checkmark" : "square.and.pencil")
                        .font(.headline).foregroundStyle(done ? MenoTheme.onTeal : MenoTheme.teal)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(done ? "Checked in" : "Evening check-in").font(.headline).foregroundStyle(MenoTheme.ink)
                    Text(done ? "Tap to edit today's answers" : "Four quick taps. Under 30 seconds.")
                        .font(.subheadline).foregroundStyle(MenoTheme.inkSecondary)
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

// MARK: - Pattern slot

struct PatternSlot: View {
    let insights: [Insight]
    @Environment(SubscriptionManager.self) private var subscription
    @Environment(AppRouter.self) private var router

    var body: some View {
        MenoCard {
            SectionHeader(title: "Pattern", trailing: insights.count > 1 ? "All" : nil) { router.tab = .week }
            if let top = insights.first {
                let t = InsightCopy.text(top)
                if subscription.isPro || !top.isPremium {
                    Label(t.title, systemImage: t.symbol).font(.headline).foregroundStyle(MenoTheme.ink)
                    Text(t.body).font(.body).foregroundStyle(MenoTheme.ink).fixedSize(horizontal: false, vertical: true)
                } else {
                    Label(t.title, systemImage: t.symbol).font(.headline).foregroundStyle(MenoTheme.ink)
                    Text("A pattern showed up in your entries. MenoMap Pro shows the numbers behind it.")
                        .font(.subheadline).foregroundStyle(MenoTheme.inkSecondary)
                    Button("See the pattern") { router.present(.paywall(.pattern)) }
                        .buttonStyle(.menoQuiet)
                }
            } else {
                EmptyState(systemImage: "sparkle.magnifyingglass", title: "No pattern yet",
                           message: "Patterns need about two weeks of check-ins.")
            }
        }
    }
}

// MARK: - Quick actions

struct QuickActions: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Quick actions").font(MenoTheme.headline(.title3)).foregroundStyle(MenoTheme.ink)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                tile("Log a past surge", "clock.arrow.circlepath") { router.present(.afterTheFact) }
                tile("Check in", "square.and.pencil") { router.present(.checkIn) }
                tile("Add medication", "pills") { router.present(.medication(nil)) }
                tile("Visit notes", "doc.text") { router.tab = .visit }
            }
        }
    }

    private func tile(_ title: LocalizedStringKey, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol).font(.body.weight(.semibold)).foregroundStyle(MenoTheme.teal).frame(width: 22)
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(MenoTheme.ink)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
            .padding(14)
            .background(MenoTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(MenoTheme.hairline))
        }
        .buttonStyle(.plain)
    }
}
