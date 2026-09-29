import SwiftUI
import MenoCore

// MARK: - Appointment follow-up (the day after) → positive moment for a review

struct AppointmentFollowUpCard: View {
    @Environment(MenoStore.self) private var store
    @Environment(AppRouter.self) private var router

    /// The most recent appointment 1–3 days ago that hasn't been answered.
    private var pending: Appointment? {
        let today = DayKey.today()
        return store.appointments().last { a in
            let d = DayKey(a.date).days(to: today)
            return a.outcome == nil && (1...3).contains(d)
        }
    }

    var body: some View {
        if let appt = pending {
            MenoCard {
                Text(appt.clinicianName.map { String(localized: "How did it go with \($0)?") } ?? String(localized: "How did your appointment go?"))
                    .font(MenoTheme.headline(.title3)).foregroundStyle(MenoTheme.ink)
                AdaptiveStack(spacing: 8) {
                    Button("Went well") { answer(appt, "good") }.buttonStyle(.menoPrimary)
                    Button("Mixed") { answer(appt, "mixed") }.buttonStyle(.menoQuiet)
                    Button("Didn't happen") { answer(appt, "missed") }.buttonStyle(.menoSecondary)
                }
            }
        }
    }

    private func answer(_ appt: Appointment, _ outcome: String) {
        appt.outcome = outcome
        appt.updatedAt = .now
        store.save()
        switch outcome {
        case "good":
            router.toast = String(localized: "Glad it helped. Keep logging and your next notes will be even sharper.")
            ReviewPrompt.recordPositiveMoment()
        case "mixed":
            router.toast = String(localized: "Next time, pick the one question that matters most.")
            router.tab = .visit
        default:
            router.tab = .visit
        }
    }
}

// MARK: - Tonight's heads-up (Pro): her own alcohol-evening pattern, on a night she marked alcohol

struct TonightHeadsUpCard: View {
    @Environment(AppContainer.self) private var container
    @Environment(MenoStore.self) private var store
    @Environment(SubscriptionManager.self) private var subscription
    @Environment(AppRouter.self) private var router

    var body: some View {
        let hour = Calendar.current.component(.hour, from: .now)
        if hour >= 17, let h = InsightEngine().tonightHeadsUp(store.insightInput(), today: .today()) {
            MenoCard {
                Label("Tonight's heads-up", systemImage: "moon.haze").font(MenoTheme.headline(.headline)).foregroundStyle(MenoTheme.ink)
                if subscription.isPro {
                    Text("You marked alcohol today. After \(h.alcoholEvenings) of your recent alcohol evenings, you logged night sweats on \(h.sweatNights). Your entries, not a forecast.")
                        .font(.body).foregroundStyle(MenoTheme.ink).fixedSize(horizontal: false, vertical: true)
                    if !container.nightWatch.isArmed {
                        Button { container.nightWatch.arm() } label: { Label("Turn on Night Watch", systemImage: "moon.stars.fill") }
                            .buttonStyle(.menoQuiet)
                    }
                } else {
                    Text("Your entries have something to say about tonight.").font(.subheadline).foregroundStyle(MenoTheme.inkSecondary)
                    Button("See it with Pro") { router.present(.paywall(.pattern)) }.buttonStyle(.menoQuiet)
                }
            }
        }
    }
}

// MARK: - Weekly Wrap (free; Sunday afternoon and Monday)

struct WeeklyWrapCard: View {
    @Environment(MenoStore.self) private var store
    @State private var sharing = false

    /// The Sunday that ends the week being wrapped (yesterday on Monday, today on Sunday).
    private var weekEnd: DayKey? {
        let today = DayKey.today()
        let hour = Calendar.current.component(.hour, from: .now)
        switch today.weekday() {
        case 1 where hour >= 12: return today
        case 2: return today.adding(days: -1)
        default: return nil
        }
    }

    var body: some View {
        let profile = store.profile()
        if let end = weekEnd, profile.weeklyWrapDismissed != end.description {
            let window = DayWindow(lastDays: 7, endingOn: end)
            let stats = StatsCalculator.compute(window: window, surges: store.surgeRecords(in: window), checkIns: store.checkInRecords(in: window))
            if stats.loggedDays >= 3 {
                MenoCard {
                    HStack {
                        Text("Your week, wrapped").font(MenoTheme.headline(.title3)).foregroundStyle(MenoTheme.ink)
                        Spacer()
                        Button { profile.weeklyWrapDismissed = end.description; store.save() } label: {
                            Image(systemName: "xmark").foregroundStyle(MenoTheme.inkSecondary).frame(width: MenoTheme.minHit, height: MenoTheme.minHit)
                        }
                        .accessibilityLabel(Text("Dismiss"))
                    }
                    Text(Copy.weekHeadline(count: stats.total, voice: profile.voice))
                        .font(MenoTheme.headline(.headline)).foregroundStyle(MenoTheme.ink)
                    HeatStrip(days: stats.days, showSleep: false)
                    HStack(spacing: 18) {
                        miniStat(stats.peakTime.map(Copy.clock) ?? "–", "Peak")
                        miniStat(stats.avgDurationSec.map(Copy.duration) ?? "–", "Typical")
                        miniStat(stats.calmestDay.map(Copy.date) ?? "–", "Calmest")
                    }
                    Button { sharing = true } label: { Label("Share my week", systemImage: "square.and.arrow.up") }
                        .buttonStyle(.menoQuiet)
                }
                .sheet(isPresented: $sharing) { ShareCardSheet(kind: .week(stats: stats)) }
            }
        }
    }

    private func miniStat(_ value: String, _ label: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.caption).foregroundStyle(MenoTheme.inkSecondary)
            Text(value).font(.system(.headline, design: .serif).monospacedDigit()).foregroundStyle(MenoTheme.ink)
        }
    }
}

// MARK: - Sample preview ("See what two weeks looks like")

struct SamplePreviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(MenoStore.self) private var store

    var body: some View {
        let today = DayKey.today()
        let input = SampleSeries.twoWeeks(endingOn: today)
        let window = DayWindow(lastDays: 14, endingOn: today)
        let stats = StatsCalculator.compute(window: window, surges: input.surges, checkIns: input.checkIns)
        let insights = InsightEngine().compute(input, today: today).prefix(2)
        let voice = store.profile().voice
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Label("Example data, not yours", systemImage: "eye")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MenoTheme.onTeal)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(MenoTheme.teal, in: Capsule())
                    Text("Two weeks of logging looks like this.")
                        .font(MenoTheme.headline(.title2)).foregroundStyle(MenoTheme.ink)
                    MenoCard {
                        SectionHeader(title: "Heat map")
                        HeatCalendar(days: stats.days)
                        HeatLegend()
                    }
                    SurgeClockCard(stats: stats, voice: voice)
                    ForEach(Array(insights)) { i in
                        let t = InsightCopy.text(i)
                        MenoCard {
                            Label(t.title, systemImage: t.symbol).font(.headline)
                            Text(t.body).font(.body).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Text("Yours starts filling in with your first surge. Most people see their first pattern in about two weeks.")
                        .font(.subheadline).foregroundStyle(MenoTheme.inkSecondary)
                    Button("Got it") { dismiss() }.buttonStyle(.menoPrimary)
                }
                .padding(16)
            }
            .menoScreen()
            .navigationTitle("Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Close") { dismiss() } } }
        }
    }
}
