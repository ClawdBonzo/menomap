import Foundation
import MenoCore

/// Turns structured insights into sentences. Tone: "Your entries show…". Never "means", "caused" or "proves".
enum InsightCopy {
    struct Text {
        let title: String
        let body: String
        let symbol: String
    }

    static func text(_ i: Insight) -> Text {
        let f = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(0...1))
        switch i.kind {
        case let .sleepAfterHeavyNights(measure, heavyN, heavyAvg, otherN, otherAvg):
            let body: String
            if measure == .score {
                body = String(localized: "On \(heavyN) nights with 3 or more surges, your sleep score averaged \(heavyAvg.formatted(f)), compared with \(otherAvg.formatted(f)) on the other \(otherN) nights.")
            } else {
                body = String(localized: "On \(heavyN) nights with 3 or more surges, Apple Health recorded \(hoursMinutes(heavyAvg)) of sleep on average, compared with \(hoursMinutes(otherAvg)) on the other \(otherN) nights.")
            }
            return Text(title: String(localized: "Heavy nights and sleep"), body: body, symbol: "bed.double")

        case let .alcoholThenSweats(yes, sweatYes, no, sweatNo):
            return Text(
                title: String(localized: "Alcohol evenings"),
                body: String(localized: "On \(yes) evenings you marked alcohol, night sweats were logged on \(sweatYes) of the nights that followed. On \(no) evenings without, \(sweatNo)."),
                symbol: "wineglass")

        case let .severityChange(recent, prior, _, _):
            return Text(
                title: recent < prior ? String(localized: "Surges running milder") : String(localized: "Surges running stronger"),
                body: String(localized: "Average surge intensity was \(recent.formatted(f)) in the last 30 days, compared with \(prior.formatted(f)) in the 30 days before."),
                symbol: "chart.line.downtrend.xyaxis")

        case let .missedDoses(skipped, perSkipped, other, perOther):
            return Text(
                title: String(localized: "Skipped doses"),
                body: String(localized: "On \(skipped) days with a skipped dose you logged \(perSkipped.formatted(f)) surges a day, compared with \(perOther.formatted(f)) on \(other) other days. That's a coincidence check, not proof of a cause."),
                symbol: "pills")

        case let .peakHour(time, share, _):
            return Text(
                title: String(localized: "Your peak hour"),
                body: String(localized: "\(Int((share * 100).rounded()))% of your surges in the last 30 days started around \(Copy.clock(time))."),
                symbol: "clock")

        case let .triggerShare(tag, share, tagged):
            return Text(
                title: String(localized: "Most-tagged: \(Copy.tag(tag))"),
                body: String(localized: "\(Copy.tag(tag)) was tagged on \(Int((share * 100).rounded()))% of your \(tagged) tagged surges in the last 30 days."),
                symbol: Copy.tagSymbol(tag))

        case let .wristTempNights(sweatN, sweatDelta, otherN, otherDelta):
            let unit = UnitTemperature.celsius
            let m = MeasurementFormatter()
            m.unitOptions = .providedUnit
            m.numberFormatter.maximumFractionDigits = 1
            m.numberFormatter.positivePrefix = "+"
            let useF = Locale.current.measurementSystem == .us
            func fmt(_ c: Double) -> String {
                let value: Measurement<UnitTemperature> = useF
                    ? Measurement(value: c * 9 / 5, unit: .fahrenheit)
                    : Measurement(value: c, unit: unit)
                return m.string(from: value)
            }
            return Text(
                title: String(localized: "Wrist temperature"),
                body: String(localized: "On \(sweatN) nights with a logged night sweat, your wrist temperature from Apple Health averaged \(fmt(sweatDelta)) from your usual, compared with \(fmt(otherDelta)) on \(otherN) other nights."),
                symbol: "thermometer.medium")

        case let .weekdayPattern(wd, avg, other):
            return Text(
                title: String(localized: "\(Copy.weekday(wd))s run warmer"),
                body: String(localized: "You logged \(avg.formatted(f)) surges on an average \(Copy.weekday(wd)), compared with \(other.formatted(f)) on other days over the last 8 weeks."),
                symbol: "calendar")

        case let .treatmentTimeline(_, name, days, before, after, _, _):
            return Text(
                title: String(localized: "Since you added \(name)"),
                body: String(localized: "You logged \(after.formatted(f)) surges a day in the \(days) days after you added \(name), compared with \(before.formatted(f)) in the \(days) days before. That's a coincidence check, not proof the medicine is the reason."),
                symbol: "pills")

        case let .cyclePhase(cycles, before, other):
            return Text(
                title: String(localized: "The days before your period"),
                body: String(localized: "Across your last \(cycles) cycles, you logged \(before.formatted(f)) surges a day in the 3 days before your period started, compared with \(other.formatted(f)) on other days."),
                symbol: "drop")

        case let .experimentResult(_, kind, measure, b, bDays, d, dDays):
            let what = measure == .nightSurges ? String(localized: "night surges") : String(localized: "surges")
            return Text(
                title: String(localized: "Experiment: \(Copy.experiment(kind))"),
                body: String(localized: "Your entries: \(b) \(what) in the \(bDays) logged days before, \(d) in the \(dDays) logged days during. That's what you logged, not proof of cause."),
                symbol: "flask")
        }
    }

    /// One-line teaser for free users (no numbers).
    static func lockedTeaser(_ i: Insight) -> String {
        text(i).title
    }

    static func hoursMinutes(_ minutes: Double) -> String {
        let f = DateComponentsFormatter()
        f.allowedUnits = [.hour, .minute]
        f.unitsStyle = .abbreviated
        return f.string(from: minutes * 60) ?? "\(Int(minutes)) min"
    }
}
