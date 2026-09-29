import Foundation

protocol AskMenoMapAnswering {
    func answer(_ question: String) -> AskAnswer
}

enum AskAnswer: Equatable {
    case matched(faq: FAQ, article: Article?)
    case fallback(String)
}

struct FAQ: Hashable {
    let question: String
    let answer: String
    let articleID: String
    let keywords: [String]
}

/// Local, ranked FAQ over the eight articles. No network, no model, no uploads.
struct AskMenoMapService: AskMenoMapAnswering {
    static var fallbackText: String {
        String(localized: "MenoMap doesn't know that yet. If you are worried, contact a clinician. If this feels urgent, use local emergency services.")
    }

    var faqs: [FAQ] { FAQLibrary.all }

    func answer(_ question: String) -> AskAnswer {
        let tokens = Self.tokens(question)
        guard !tokens.isEmpty else { return .fallback(Self.fallbackText) }
        var best: (FAQ, Int)?
        for f in faqs {
            let hay = Set(Self.tokens(f.question) + f.keywords.flatMap(Self.tokens))
            let score = tokens.filter { t in hay.contains(t) || hay.contains { $0.hasPrefix(t) && t.count >= 4 } }.count
            if score > (best?.1 ?? 0) { best = (f, score) }
        }
        guard let (faq, score) = best, score >= 1 else { return .fallback(Self.fallbackText) }
        return .matched(faq: faq, article: ArticleLibrary.article(id: faq.articleID))
    }

    /// Search over titles + FAQ questions for the library search field.
    func search(_ query: String) -> (articles: [Article], faqs: [FAQ]) {
        let tokens = Self.tokens(query)
        guard !tokens.isEmpty else { return (ArticleLibrary.all, []) }
        let arts = ArticleLibrary.all.filter { a in
            let hay = Self.tokens(a.title + " " + a.summary)
            return tokens.contains { t in hay.contains { $0.hasPrefix(t) } }
        }
        let fs = faqs.filter { f in
            let hay = Self.tokens(f.question) + f.keywords.flatMap(Self.tokens)
            return tokens.contains { t in hay.contains { $0.hasPrefix(t) } }
        }
        return (arts, fs)
    }

    private static let stop: Set<String> = ["the", "a", "an", "is", "i", "my", "do", "to", "of", "and", "or", "can", "what", "why", "how",
                                            "it", "in", "at", "for", "me", "am", "are", "be", "with", "about", "should", "does", "this", "that"]

    static func tokens(_ s: String) -> [String] {
        s.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 1 && !stop.contains($0) }
    }
}

enum FAQLibrary {
    static var all: [FAQ] {
        [
            FAQ(question: String(localized: "Why do I wake at 3am?"),
                answer: String(localized: "Night sweats, needing the bathroom, alcohol wearing off and a racing mind are common reasons. Log your nights for two weeks and look at the pattern."),
                articleID: "sleep", keywords: ["wake", "waking", "3am", "night", "insomnia", "awake"]),
            FAQ(question: String(localized: "Is brain fog common?"),
                answer: String(localized: "Many people notice changes in memory and focus around menopause, and poor sleep can add to it. Track it in your check-in and mention it at your visit."),
                articleID: "vasomotor", keywords: ["brain", "fog", "memory", "forgetful", "focus", "concentration"]),
            FAQ(question: String(localized: "What do I bring to the doctor?"),
                answer: String(localized: "Two to four weeks of notes, your medication list, and your top three questions. The Visit tab puts all of that on one page."),
                articleID: "using-report", keywords: ["doctor", "appointment", "visit", "bring", "gp", "clinician", "report", "pdf"]),
            FAQ(question: String(localized: "Can I ask about HRT?"),
                answer: String(localized: "Yes. Asking whether hormone therapy is an option for you, and why or why not, is a very reasonable question."),
                articleID: "hormone-therapy", keywords: ["hrt", "mht", "hormone", "estrogen", "oestrogen", "therapy", "replacement"]),
            FAQ(question: String(localized: "Am I in perimenopause?"),
                answer: String(localized: "Only a clinician can evaluate that. What MenoMap can do is show what you logged."),
                articleID: "stages", keywords: ["perimenopause", "peri", "stage", "starting", "am", "menopause", "diagnose"]),
            FAQ(question: String(localized: "Do I have menopause?"),
                answer: String(localized: "Only a clinician can evaluate that. What MenoMap can do is show what you logged."),
                articleID: "stages", keywords: ["menopause", "have", "diagnosis", "test", "blood"]),
            FAQ(question: String(localized: "How long do hot flashes last?"),
                answer: String(localized: "Each one often lasts a few minutes. How many months or years they continue varies a lot from person to person."),
                articleID: "vasomotor", keywords: ["long", "last", "duration", "years", "stop", "end", "flash", "flush"]),
            FAQ(question: String(localized: "What triggers hot flashes?"),
                answer: String(localized: "People often notice alcohol, caffeine, spicy food, heat and stress, but it varies. Tag your surges and MenoMap will show which tags come up most for you."),
                articleID: "vasomotor", keywords: ["trigger", "triggers", "cause", "alcohol", "caffeine", "spicy", "wine"]),
            FAQ(question: String(localized: "Are night sweats normal?"),
                answer: String(localized: "They're very common around menopause. Sweats with fever, weight loss or feeling unwell are worth checking with a clinician."),
                articleID: "vasomotor", keywords: ["night", "sweats", "sweating", "soaked", "normal"]),
            FAQ(question: String(localized: "What can I do without hormones?"),
                answer: String(localized: "There are non-hormonal medicines, CBT and practical changes. A clinician can help you choose."),
                articleID: "non-hormonal", keywords: ["without", "non", "hormonal", "natural", "alternative", "cbt", "options"]),
            FAQ(question: String(localized: "Do supplements work?"),
                answer: String(localized: "Evidence is mixed for many supplements, and some interact with medicines. Tell your clinician or pharmacist what you take."),
                articleID: "non-hormonal", keywords: ["supplement", "supplements", "herbal", "black", "cohosh", "vitamin", "natural"]),
            FAQ(question: String(localized: "I had bleeding after menopause"),
                answer: String(localized: "Bleeding after menopause — even once, even light — should be checked by a clinician. MenoMap cannot tell you why it happened."),
                articleID: "bleeding-after-menopause", keywords: ["bleeding", "bleed", "spotting", "blood", "period", "came", "back"]),
            FAQ(question: String(localized: "Should I stop my medication?"),
                answer: String(localized: "MenoMap cannot tell you to start, stop, or change a medicine. Bring your list to a clinician."),
                articleID: "hormone-therapy", keywords: ["stop", "start", "change", "dose", "medication", "medicine", "pills", "increase"]),
            FAQ(question: String(localized: "Is my HRT working?"),
                answer: String(localized: "MenoMap can show your surges before and after you started, as a coincidence check. Whether a treatment is right for you is a question for your clinician."),
                articleID: "hormone-therapy", keywords: ["working", "work", "effective", "helping", "hrt"]),
            FAQ(question: String(localized: "My heart is racing"),
                answer: String(localized: "Heart sensations have many causes. If they are new, severe, or come with chest pain, shortness of breath, or fainting, seek care now."),
                articleID: "vasomotor", keywords: ["heart", "racing", "palpitations", "pounding", "fluttering", "chest"]),
            FAQ(question: String(localized: "How do I sleep cooler?"),
                answer: String(localized: "A cool, dark room, a fan, breathable bedding and layers you can shed often help. Try it as a two-week experiment."),
                articleID: "sleep", keywords: ["cool", "cooler", "fan", "bedding", "sheets", "hot", "bed", "sleep"]),
            FAQ(question: String(localized: "Why track my symptoms?"),
                answer: String(localized: "Notes show how often, how strong and what's changing, which is hard to remember in a short appointment."),
                articleID: "diary", keywords: ["track", "tracking", "diary", "log", "why", "journal"]),
            FAQ(question: String(localized: "Is alcohol making it worse?"),
                answer: String(localized: "For some people it does. Mark alcohol in your check-in; after two weeks MenoMap can compare your nights with and without it."),
                articleID: "vasomotor", keywords: ["alcohol", "wine", "drink", "drinking", "beer"]),
            FAQ(question: String(localized: "Can menopause affect mood?"),
                answer: String(localized: "Many people notice mood changes, irritability or anxiety around this time. If low mood is persistent or you feel unsafe, contact a clinician or local emergency services."),
                articleID: "stages", keywords: ["mood", "anxiety", "anxious", "irritable", "depressed", "low", "sad", "rage"]),
            FAQ(question: String(localized: "What does MenoMap do with my data?"),
                answer: String(localized: "It stays on your iPhone. Nothing is uploaded. You can export or delete everything from You → Privacy."),
                articleID: "using-report", keywords: ["data", "privacy", "private", "upload", "share", "cloud", "delete"]),
        ]
    }
}
