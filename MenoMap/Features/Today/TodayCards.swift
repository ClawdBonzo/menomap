import SwiftUI
import MenoCore

/// Morning card: last night pre-filled from MenoMap, the Watch and Apple Health; confirm with one tap.
struct MorningCard: View {
    @Environment(MenoStore.self) private var store
    @Environment(AppRouter.self) private var router
    @AppStorage("meno.morning.confirmed") private var confirmedDay = ""

    var body: some View {
        let today = DayKey.today()
        let hour = Calendar.current.component(.hour, from: .now)
        let nightSurges = store.surgeRecords(in: DayWindow(lastDays: 2, endingOn: today))
            .filter { $0.nightKey() == today && $0.isNight() }
        let health = store.healthNights().first { $0.morningKey == today.description }
        if (5..<12).contains(hour), confirmedDay != today.description, !nightSurges.isEmpty || health?.minutesAsleep != nil {
            MenoCard {
                HStack {
                    Label("Last night", systemImage: "moon.stars").font(MenoTheme.headline(.title3)).foregroundStyle(MenoTheme.ink)
                    Spacer()
                }
                VStack(alignment: .leading, spacing: 6) {
                    let sweats = nightSurges.count
                    Text(sweats == 0 ? String(localized: "No night surges logged") : Copy.kindPlural(.nightSweat, count: sweats))
                        .font(.title3.weight(.semibold)).foregroundStyle(MenoTheme.ink)
                    if let m = health?.minutesAsleep {
                        Text("\(InsightCopy.hoursMinutes(Double(m))) asleep · from Apple Health")
                            .font(.subheadline).foregroundStyle(MenoTheme.inkSecondary)
                    }
                    if let t = health?.wristTempDelta {
                        Text("Wrist temperature \(t >= 0 ? "+" : "")\(t.formatted(.number.precision(.fractionLength(1))))° from your usual · from Apple Health")
                            .font(.subheadline).foregroundStyle(MenoTheme.inkSecondary)
                    }
                }
                Text("Right?").font(.headline).foregroundStyle(MenoTheme.ink)
                AdaptiveStack(spacing: 10) {
                    Button("That's right") { withAnimation { confirmedDay = today.description } }
                        .buttonStyle(.menoPrimary)
                    Button("Add one I missed") { router.present(.afterTheFact) }
                        .buttonStyle(.menoSecondary)
                }
            }
        }
    }
}

/// Reminder after bleeding was logged post-menopause (here or in Apple Health). Non-diagnostic.
struct BleedingReminderCard: View {
    @Environment(MenoStore.self) private var store

    var body: some View {
        let since = Date.now.addingTimeInterval(-30 * 86400)
        let logged = store.cycleNotes().contains { $0.isPostMenopauseFlag && $0.start >= since }
        let fromHealth = store.healthSymptoms().contains { $0.typeRaw.contains("BleedingAfterMenopause") && $0.date >= since }
        if logged || fromHealth {
            SafetyBanner(title: BleedingCopy.title, message: BleedingCopy.message)
        }
    }
}

enum BleedingCopy {
    static var title: String { String(localized: "Bleeding after menopause") }
    static var message: String {
        String(localized: "Bleeding after menopause — even once, even light — should be checked by a clinician. MenoMap cannot tell you why it happened.")
    }
}

/// Appointment countdown + readiness meter (the reason to log daily; no streaks).
struct AppointmentCard: View {
    @Environment(MenoStore.self) private var store
    @Environment(AppRouter.self) private var router

    var body: some View {
        if let appt = store.nextAppointment() {
            let r = VisitReadinessCalculator.readiness(store: store, appointment: appt)
            let days = DayKey.today().days(to: DayKey(appt.date))
            Button { router.tab = .visit } label: {
                HStack(spacing: 16) {
                    ReadinessRing(value: r.score).frame(width: 64, height: 64)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(AppointmentText.countdown(appt, days: days))
                            .font(MenoTheme.headline(.headline)).foregroundStyle(MenoTheme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Notes \(Int(r.score * 100))% ready")
                            .font(.subheadline.weight(.semibold)).foregroundStyle(MenoTheme.teal)
                        if let gap = r.gaps.first {
                            Text(AppointmentText.gap(gap)).font(.caption).foregroundStyle(MenoTheme.inkSecondary)
                        }
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").foregroundStyle(MenoTheme.inkSecondary)
                }
                .padding(16)
                .background(MenoTheme.surface, in: RoundedRectangle(cornerRadius: MenoTheme.radiusCard, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: MenoTheme.radiusCard, style: .continuous).strokeBorder(MenoTheme.hairline))
            }
            .buttonStyle(.plain)
        }
    }
}

enum AppointmentText {
    static func countdown(_ appt: Appointment, days: Int) -> String {
        let who = appt.clinicianName.flatMap { $0.isEmpty ? nil : $0 }
        switch days {
        case 0: return who.map { String(localized: "\($0) today") } ?? String(localized: "Appointment today")
        case 1: return who.map { String(localized: "\($0) tomorrow") } ?? String(localized: "Appointment tomorrow")
        default: return who.map { String(localized: "\($0) in \(days) days") } ?? String(localized: "Appointment in \(days) days")
        }
    }

    static func gap(_ g: VisitReadiness.Gap) -> String {
        switch g {
        case .moreLoggedDays: String(localized: "Next: log on a few more days")
        case .logSurges: String(localized: "Next: log surges as they happen")
        case .checkIns: String(localized: "Next: a few evening check-ins")
        case .medications: String(localized: "Next: add your medications (or confirm none)")
        case .questions: String(localized: "Next: pick questions to ask")
        }
    }
}

struct ReadinessRing: View {
    let value: Double
    var lineWidth: CGFloat = 7

    var body: some View {
        ZStack {
            Circle().stroke(MenoTheme.hairline, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.02, value))
                .stroke(MenoTheme.teal, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int(value * 100))%")
                .font(.system(.subheadline, design: .serif).weight(.semibold).monospacedDigit())
                .foregroundStyle(MenoTheme.ink)
        }
        .accessibilityElement()
        .accessibilityLabel(Text("Notes \(Int(value * 100)) percent ready"))
    }
}

struct ExperimentCard: View {
    @Environment(MenoStore.self) private var store
    @Environment(AppRouter.self) private var router

    var body: some View {
        if let e = store.activeExperiment()?.record {
            let day = e.startDay.days(to: .today()) + 1
            Button { router.tab = .week } label: {
                HStack(spacing: 14) {
                    Image(systemName: "flask").font(.title2).foregroundStyle(MenoTheme.teal)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(Copy.experiment(e.kind, custom: e.customTitle)).font(.headline).foregroundStyle(MenoTheme.ink)
                        Text("Day \(min(day, e.lengthDays)) of \(e.lengthDays)").font(.subheadline).foregroundStyle(MenoTheme.inkSecondary)
                        ProgressView(value: Double(min(day, e.lengthDays)), total: Double(e.lengthDays)).tint(MenoTheme.teal)
                    }
                }
                .padding(16)
                .background(MenoTheme.surface, in: RoundedRectangle(cornerRadius: MenoTheme.radiusCard, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: MenoTheme.radiusCard, style: .continuous).strokeBorder(MenoTheme.hairline))
            }
            .buttonStyle(.plain)
        }
    }
}
