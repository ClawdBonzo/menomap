import Foundation
import MenoCore

/// Shared labels and voice-dependent copy. Wry lines are only used for stats, share cards and empty states;
/// safety, legal, Learn and the PDF always use the straight wording.
enum Copy {
    static func kind(_ k: SurgeKind) -> String {
        switch k {
        case .hotFlash: String(localized: "Hot flash")
        case .nightSweat: String(localized: "Night sweat")
        }
    }

    static func kindPlural(_ k: SurgeKind, count: Int) -> String {
        switch k {
        case .hotFlash: String(localized: "\(count) hot flashes")
        case .nightSweat: String(localized: "\(count) night sweats")
        }
    }

    static func tag(_ t: SurgeTag) -> String {
        switch t {
        case .alcohol: String(localized: "Alcohol")
        case .heat: String(localized: "Heat")
        case .stress: String(localized: "Stress")
        case .exercise: String(localized: "Exercise")
        case .caffeine: String(localized: "Caffeine")
        case .spicyFood: String(localized: "Spicy food")
        case .unknown: String(localized: "Not sure")
        }
    }

    static func tagSymbol(_ t: SurgeTag) -> String {
        switch t {
        case .alcohol: "wineglass"
        case .heat: "sun.max"
        case .stress: "bolt.heart"
        case .exercise: "figure.walk"
        case .caffeine: "cup.and.saucer"
        case .spicyFood: "flame"
        case .unknown: "questionmark"
        }
    }

    static func intensityWord(_ i: Int) -> String {
        switch i {
        case 1: String(localized: "Mild")
        case 2: String(localized: "Noticeable")
        case 3: String(localized: "Strong")
        case 4: String(localized: "Very strong")
        default: String(localized: "Intense")
        }
    }

    static func metric(_ m: TrackedMetric) -> String {
        switch m {
        case .sleep: String(localized: "Sleep")
        case .hotFlashes: String(localized: "Hot flashes today")
        case .mood: String(localized: "Mood")
        case .energy: String(localized: "Energy")
        case .nightSweats: String(localized: "Night sweats")
        case .brainFog: String(localized: "Brain fog")
        case .stress: String(localized: "Stress")
        }
    }

    static func metricShort(_ m: TrackedMetric) -> String {
        switch m {
        case .hotFlashes: String(localized: "Hot flashes")
        default: metric(m)
        }
    }

    /// Anchors for the 0 and 10 ends of the check-in scale.
    static func metricAnchors(_ m: TrackedMetric) -> (low: String, high: String) {
        switch m {
        case .sleep: (String(localized: "Awful"), String(localized: "Great"))
        case .hotFlashes: (String(localized: "None"), String(localized: "Constant"))
        case .mood: (String(localized: "Low"), String(localized: "Great"))
        case .energy: (String(localized: "Empty"), String(localized: "Full"))
        case .nightSweats: (String(localized: "None"), String(localized: "Drenched"))
        case .brainFog: (String(localized: "Clear"), String(localized: "Thick fog"))
        case .stress: (String(localized: "Calm"), String(localized: "Maxed out"))
        }
    }

    static func metricSymbol(_ m: TrackedMetric) -> String {
        switch m {
        case .sleep: "bed.double"
        case .hotFlashes: "flame"
        case .mood: "face.smiling"
        case .energy: "battery.75percent"
        case .nightSweats: "drop"
        case .brainFog: "cloud.fog"
        case .stress: "waveform.path.ecg"
        }
    }

    static func stage(_ s: MenopauseStage) -> String {
        switch s {
        case .perimenopause: String(localized: "Perimenopause")
        case .menopause: String(localized: "Menopause")
        case .postmenopause: String(localized: "Post-menopause")
        case .notSure: String(localized: "Not sure")
        case .preferNotToSay: String(localized: "Prefer not to say")
        }
    }

    static func medCategory(_ c: MedicationCategory) -> String {
        switch c {
        case .estrogen: String(localized: "Estrogen")
        case .progestogen: String(localized: "Progestogen")
        case .combined: String(localized: "Combined")
        case .vaginalEstrogen: String(localized: "Vaginal estrogen")
        case .nonHormonal: String(localized: "Non-hormonal")
        case .supplement: String(localized: "Supplement")
        case .other: String(localized: "Other")
        }
    }

    static func flow(_ f: Flow) -> String {
        switch f {
        case .spotting: String(localized: "Spotting")
        case .light: String(localized: "Light")
        case .medium: String(localized: "Medium")
        case .heavy: String(localized: "Heavy")
        }
    }

    static func experiment(_ k: ExperimentKind, custom: String? = nil) -> String {
        switch k {
        case .noAlcoholAfter7: String(localized: "No alcohol after 7pm")
        case .noCaffeineAfterNoon: String(localized: "No caffeine after noon")
        case .coolerBedroom: String(localized: "Cooler bedroom")
        case .eveningBreathing: String(localized: "Evening breathing")
        case .custom: custom ?? String(localized: "My experiment")
        }
    }

    static func experimentHow(_ k: ExperimentKind) -> String {
        switch k {
        case .noAlcoholAfter7: String(localized: "Skip alcohol after 7pm for two weeks. Keep logging surges as usual.")
        case .noCaffeineAfterNoon: String(localized: "Coffee, tea and cola before noon only, for two weeks.")
        case .coolerBedroom: String(localized: "Fan, window or a lower thermostat at night, for two weeks.")
        case .eveningBreathing: String(localized: "Five minutes of slow breathing before bed, for two weeks.")
        case .custom: String(localized: "Pick one change and keep it for two weeks.")
        }
    }

    static func duration(_ seconds: Int) -> String {
        guard seconds > 0 else { return String(localized: "Unknown length") }
        let f = DateComponentsFormatter()
        f.allowedUnits = seconds >= 3600 ? [.hour, .minute] : [.minute, .second]
        f.unitsStyle = .abbreviated
        return f.string(from: TimeInterval(seconds)) ?? "\(seconds)s"
    }

    static func clock(_ t: ClockTime) -> String {
        let d = Calendar.current.date(from: DateComponents(hour: t.hour, minute: t.minute)) ?? .now
        return d.formatted(date: .omitted, time: .shortened)
    }

    static func weekday(_ wd: Int) -> String {
        let symbols = Calendar.current.weekdaySymbols
        return symbols.indices.contains(wd - 1) ? symbols[wd - 1] : ""
    }

    static func shortWeekday(_ day: DayKey) -> String {
        day.startDate().formatted(.dateTime.weekday(.narrow))
    }

    static func date(_ day: DayKey) -> String {
        day.startDate().formatted(.dateTime.day().month(.abbreviated))
    }

    // MARK: Voice

    /// Headline for a week's surge total on stats/share cards.
    static func weekHeadline(count: Int, voice: VoiceStyle) -> String {
        switch voice {
        case .wry:
            count == 0 ? String(localized: "Zero personal summers this week.") :
                String(localized: "\(count) personal summers this week.")
        case .straight:
            String(localized: "\(count) surges this week")
        }
    }

    static func peakLine(_ t: ClockTime, voice: VoiceStyle) -> String {
        let time = clock(t)
        switch voice {
        case .wry:
            return (t.hour >= 1 && t.hour < 5) ? String(localized: "Peak hour: \(time). Rude.") : String(localized: "Peak hour: \(time).")
        case .straight:
            return String(localized: "Most surges around \(time)")
        }
    }

    static func calmStretchLine(_ days: Int, voice: VoiceStyle) -> String {
        switch voice {
        case .wry: days >= 3 ? String(localized: "Longest calm stretch: \(days) days. Frame it.") : String(localized: "Longest calm stretch: \(days) days.")
        case .straight: String(localized: "Longest calm stretch: \(days) days")
        }
    }

    static func savedLine(seconds: Int, voice: VoiceStyle) -> String {
        switch voice {
        case .wry: String(localized: "Saved. \(duration(seconds)) of weather, logged.")
        case .straight: String(localized: "Saved · \(duration(seconds))")
        }
    }
}
