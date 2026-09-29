import Foundation

/// Questions the user may ask; never answers. Keys are stored on the Appointment.
enum VisitQuestions {
    static let general = ["disruptive", "changed", "watchFor", "medsFit", "hormoneOption"]

    static func forTopic(_ t: VisitTopic) -> [String] {
        switch t {
        case .hotFlashes: ["hotFlashOptions"]
        case .nightSweats: ["nightSweatOther"]
        case .sleep: ["sleepOther"]
        case .mood: ["moodAddress"]
        case .bleeding: ["bleedingCheck"]
        case .currentTreatment: ["treatmentReview"]
        case .vaginalUrinary: ["vaginalUrinary"]
        case .weight: ["weight"]
        case .other: []
        }
    }

    static func suggested(for topics: [VisitTopic]) -> [String] {
        var out = general
        for t in topics { for q in forTopic(t) where !out.contains(q) { out.append(q) } }
        return out
    }

    static func text(_ key: String, bundle: Bundle = .main) -> String {
        if key.hasPrefix("custom:") { return String(key.dropFirst(7)) }
        switch key {
        case "disruptive": return String(localized: "Which of these is most disruptive for me?", bundle: bundle)
        case "changed": return String(localized: "When did this start, and has it changed?", bundle: bundle)
        case "watchFor": return String(localized: "What should I watch for that means I should call?", bundle: bundle)
        case "medsFit": return String(localized: "How do my current medications fit this picture?", bundle: bundle)
        case "hormoneOption": return String(localized: "Is hormone therapy an option for me, and why or why not?", bundle: bundle)
        case "hotFlashOptions": return String(localized: "What are my options for hot flashes, hormonal and non-hormonal?", bundle: bundle)
        case "nightSweatOther": return String(localized: "Could anything besides menopause be causing my night sweats?", bundle: bundle)
        case "sleepOther": return String(localized: "Could something other than night sweats be affecting my sleep?", bundle: bundle)
        case "moodAddress": return String(localized: "Is what I'm noticing with my mood something we should look at?", bundle: bundle)
        case "bleedingCheck": return String(localized: "Does the bleeding I logged need to be checked, and how?", bundle: bundle)
        case "treatmentReview": return String(localized: "Is my current treatment still the right fit, and when should we review it?", bundle: bundle)
        case "vaginalUrinary": return String(localized: "What can help with vaginal or urinary symptoms?", bundle: bundle)
        case "weight": return String(localized: "What's realistic for weight and body changes at this stage?", bundle: bundle)
        default: return key
        }
    }

    static func topic(_ t: VisitTopic) -> String {
        switch t {
        case .hotFlashes: String(localized: "Hot flashes")
        case .nightSweats: String(localized: "Night sweats")
        case .sleep: String(localized: "Sleep")
        case .mood: String(localized: "Mood")
        case .bleeding: String(localized: "Bleeding")
        case .currentTreatment: String(localized: "Treatment I take")
        case .vaginalUrinary: String(localized: "Vaginal / urinary")
        case .weight: String(localized: "Weight")
        case .other: String(localized: "Other")
        }
    }
}
