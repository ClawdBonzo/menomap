import Foundation

/// Static education content. General information only; never advice for a specific person.
/// `needsSourceReview` stays true until each source URL is fetched and checked (Docs/SPEC_ADDITIONS §9).
struct Article: Identifiable, Hashable {
    enum Category: String { case basics, symptoms, care, visit }

    let id: String
    let category: Category
    let title: String
    let summary: String
    let body: String
    let sourceName: String?
    var sourceURL: URL?
    var reviewedAt: Date?
    var needsSourceReview: Bool

    var symbol: String {
        switch category {
        case .basics: "book"
        case .symptoms: "flame"
        case .care: "cross.case"
        case .visit: "doc.text"
        }
    }
}

enum ArticleLibrary {
    static var all: [Article] { [stages, vasomotor, sleep, diary, hormoneTherapy, nonHormonal, bleeding, usingReport] }

    static func article(id: String) -> Article? { all.first { $0.id == id } }

    /// Date every linked source was fetched and checked against the article (2026-09-29).
    /// NICE NG23 blocks automated fetching, so it is named in the text but not linked.
    static let checkedOn = DateComponents(calendar: Calendar(identifier: .gregorian), year: 2026, month: 9, day: 29).date

    static var stages: Article {
        Article(
            id: "stages", category: .basics,
            title: String(localized: "Perimenopause and menopause: what the words mean"),
            summary: String(localized: "Three stages, and why the lines between them are blurry."),
            body: String(localized: """
            **Menopause** is a single point in time: the day that marks 12 months in a row without a period, when that isn't explained by something else (like pregnancy, some medicines, or surgery). In many countries it happens on average in the early 50s, but anywhere from the mid-40s to the mid-50s is common.

            **Perimenopause** is the stretch of years leading up to that point. Hormone levels rise and fall unevenly, so periods can become irregular, heavier, lighter, closer together or further apart. Many of the changes people associate with menopause, like hot flashes, night sweats, sleep changes and mood changes, often start here, while periods are still happening. Perimenopause can last a few years or quite a bit longer, and it looks different for everyone.

            **Post-menopause** is everything after that 12-month mark. Some symptoms settle over time; others can continue for years.

            Menopause can also happen earlier because of surgery that removes the ovaries, some cancer treatments, or other health conditions. Menopause before 40 is sometimes called premature ovarian insufficiency, and it's worth discussing with a clinician.

            **How it's recognized.** For many people over 45, clinicians recognize perimenopause or menopause from your history and symptoms. Blood tests aren't always needed, because hormone levels swing from day to day. They're more likely to be used when someone is younger or the picture is unclear.

            **What MenoMap does and doesn't do.** MenoMap can't tell you which stage you're in. What it can do is keep an honest record of what you notice: surges, sleep, mood and treatment, so you and your clinician can look at the same picture.
            """),
            sourceName: "NHS; The Menopause Society", sourceURL: URL(string: "https://www.nhs.uk/conditions/menopause/"), reviewedAt: ArticleLibrary.checkedOn, needsSourceReview: false)
    }

    static var vasomotor: Article {
        Article(
            id: "vasomotor", category: .symptoms,
            title: String(localized: "Hot flashes and night sweats"),
            summary: String(localized: "Very common, very variable, and worth describing well."),
            body: String(localized: """
            Clinicians call hot flashes and night sweats **vasomotor symptoms**. A hot flash is a sudden wave of heat, often in the face, neck and chest, sometimes with flushing, sweating, a racing heart or a chill afterward. A night sweat is the same thing during sleep, and it can be strong enough to wake you or soak your sheets.

            They are among the most common changes around menopause. Some people have a few mild ones; others have many a day that disrupt work and sleep. For some they fade within a few years; for others they last much longer.

            **What can make them more likely.** People often notice patterns with alcohol, caffeine, spicy food, hot rooms, stress or heavy bedding. These vary a lot from person to person, which is why tracking your own tags can be more useful than a general list.

            **Other causes exist.** Flushing and sweating can also come from thyroid problems, infections, some medicines, anxiety and other conditions. If your symptoms don't fit the usual pattern, or come with weight loss, fever or feeling unwell, mention it to a clinician.

            **Describing them well.** Useful details for a visit:
            - How many a day and a night, roughly
            - How strong they feel and how long they last
            - What they interrupt: sleep, work, conversations, exercise
            - What seems to come before them
            - What you've tried, and whether it changed anything

            MenoMap's Surge button and after-the-fact log exist to capture exactly this without much effort.

            **Help is available.** There are hormonal and non-hormonal treatment options, plus practical approaches. Which ones suit you is a conversation to have with a clinician.
            """),
            sourceName: "The Menopause Society; NHS", sourceURL: URL(string: "https://menopause.org/patient-education"), reviewedAt: ArticleLibrary.checkedOn, needsSourceReview: false)
    }

    static var sleep: Article {
        Article(
            id: "sleep", category: .symptoms,
            title: String(localized: "Sleep changes: many causes, not one"),
            summary: String(localized: "Why 3am waking happens, and what to note."),
            body: String(localized: """
            Poor sleep is one of the most common complaints in midlife, and it rarely has a single cause.

            **Night sweats** can wake you directly, or leave you too hot or damp to settle again.

            **Other common contributors:**
            - Needing to pass urine at night
            - Anxiety or a racing mind
            - Alcohol, which can help you fall asleep but tends to fragment the second half of the night
            - Caffeine later in the day
            - Pain, restless legs, or a partner's snoring
            - Snoring or pauses in breathing, which can be a sign of sleep apnea (worth raising, especially if you're very sleepy in the day)

            **What tends to help people.** A cool, dark room; breathable bedding and layers you can shed; a steady wake-up time; and less alcohol close to bed. Cognitive behavioral therapy for insomnia (CBT-I) is a structured, well-studied approach, and many clinicians can point you to it.

            **What to track.** For a week or two, note your sleep score, night surges, alcohol and late caffeine. MenoMap's evening check-in and the Surge log do this in a few taps. If you use Apple Watch, MenoMap can show your sleep and wrist temperature from Apple Health next to your night sweats, as context rather than an explanation.

            **When to get checked.** Talk to a clinician if poor sleep is affecting your safety (for example, driving), your mood, or your daily life, or if you notice pauses in your breathing or gasping at night.
            """),
            sourceName: "NHS", sourceURL: URL(string: "https://www.nhs.uk/conditions/insomnia/"), reviewedAt: ArticleLibrary.checkedOn, needsSourceReview: false)
    }

    static var diary: Article {
        Article(
            id: "diary", category: .visit,
            title: String(localized: "Why a symptom diary helps at an appointment"),
            summary: String(localized: "Appointments are short. Memory is kind. Notes are exact."),
            body: String(localized: """
            Most appointments are short, and it's hard to remember a month of nights on the spot. People tend to recall the most recent days or the worst ones. A simple record fills the gap.

            **What a diary gives your clinician:**
            - How often symptoms happen and how strong they are, not just that they happen
            - Whether things are getting better, worse or staying the same
            - What was going on around them: sleep, alcohol, stress, medicines
            - A starting point to compare against if you try a treatment

            **Keep it light.** A diary only helps if you keep it. MenoMap is built around a one-tap Surge button and a four-question evening check-in, so it takes seconds, not a notebook.

            **Two weeks is a good start.** Two to four weeks of entries usually show a clearer picture than a single bad week.

            **Bring your questions too.** Write down what matters most to you: the symptom that bothers you most, what you want to try or avoid, and anything that worries you. MenoMap's Visit tab helps you pick questions and prints them with your notes.
            """),
            sourceName: nil, sourceURL: nil, reviewedAt: nil, needsSourceReview: false)
    }

    static var hormoneTherapy: Article {
        Article(
            id: "hormone-therapy", category: .care,
            title: String(localized: "Hormone therapy is a decision to make with a clinician"),
            summary: String(localized: "What it is, and the questions worth asking."),
            body: String(localized: """
            Hormone therapy (often called HRT or MHT) replaces some of the estrogen the body makes less of around menopause. Major guidelines describe it as an effective treatment for hot flashes and night sweats for many people, and it can help with other symptoms too.

            **It comes in different forms:** patches, gels, sprays, tablets, and low-dose vaginal products for local symptoms like dryness. People who still have a uterus are usually prescribed a progestogen alongside estrogen to protect the lining of the womb.

            **Benefits and risks depend on the person:** age, how long since periods stopped, personal and family history (for example of breast cancer, blood clots, stroke or heart disease), and the type and route of treatment. That's why it's a decision to make with a clinician who knows your history, not something an app can decide.

            **Questions people often ask:**
            - Is hormone therapy an option for me, and why or why not?
            - Which type and form would you suggest, and why?
            - What benefits could I expect, and how soon?
            - What are my personal risks, and how do they compare with not treating?
            - What should I watch for, and when should we review it?

            **If you already take it,** log it in MenoMap (You → Medications). MenoMap will show your surges before and after you started, as a coincidence check and not proof, so you have something concrete to discuss at review.

            MenoMap never suggests starting, stopping or changing a medicine.
            """),
            sourceName: "NHS; The Menopause Society", sourceURL: URL(string: "https://www.nhs.uk/medicines/hormone-replacement-therapy-hrt/"), reviewedAt: ArticleLibrary.checkedOn, needsSourceReview: false)
    }

    static var nonHormonal: Article {
        Article(
            id: "non-hormonal", category: .care,
            title: String(localized: "Non-hormonal approaches exist"),
            summary: String(localized: "Options for people who can't or don't want to use hormones."),
            body: String(localized: """
            Hormone therapy isn't right for everyone, and some people simply prefer other routes. There are several.

            **Prescription options.** Some non-hormonal medicines have evidence for reducing hot flashes. These include certain medicines originally developed for other conditions, and a newer class designed specifically for hot flashes. Each has its own benefits, side effects and interactions, so a clinician can help you weigh them.

            **Talking and mind-body approaches.** Cognitive behavioral therapy (CBT) adapted for menopause has evidence for making hot flashes and night sweats less bothersome and for improving sleep. Clinical hypnosis has also been studied.

            **Practical changes people find helpful:**
            - Layers you can remove quickly
            - A fan at your desk and bedside
            - A cooler bedroom and breathable bedding
            - Noticing and easing personal triggers (MenoMap's tags and experiments help here)
            - Regular activity and a steady sleep routine

            **Supplements and herbal products.** Evidence is mixed or limited for many of them, quality varies, and some interact with other medicines. Tell your clinician or pharmacist about anything you take, including over-the-counter products.

            **Try one change at a time.** MenoMap's two-week experiments compare your own entries before and during a change, which is easier to judge than a feeling.
            """),
            sourceName: "NHS; The Menopause Society", sourceURL: URL(string: "https://www.nhs.uk/conditions/menopause/treatment/"), reviewedAt: ArticleLibrary.checkedOn, needsSourceReview: false)
    }

    static var bleeding: Article {
        Article(
            id: "bleeding-after-menopause", category: .care,
            title: String(localized: "Bleeding after menopause should be checked"),
            summary: String(localized: "Even once, even light."),
            body: String(localized: """
            Once you've gone 12 months without a period, **any vaginal bleeding should be checked by a clinician**, even if it happened only once, and even if it was only spotting or light pink or brown discharge.

            Most of the time the cause turns out not to be serious. Thinning of the vaginal or womb lining is common, for example. But bleeding after menopause can sometimes be an early sign of a condition that's much easier to treat when found early. That's why public health guidance says to get it looked at rather than wait.

            **If you take hormone therapy,** some bleeding patterns can be expected, depending on the type you take. Bleeding that's unexpected for your treatment, heavier than usual, or happening at the wrong time should also be checked.

            **What to do:**
            - Contact your clinician or health service and say you've had bleeding after menopause.
            - Note the date, how much, and anything else you noticed. MenoMap can hold this for you (You → Cycle).

            MenoMap can't tell you why bleeding happened. It will remind you to get it checked and include it in your visit notes.
            """),
            sourceName: "NHS", sourceURL: URL(string: "https://www.nhs.uk/conditions/post-menopausal-bleeding/"), reviewedAt: ArticleLibrary.checkedOn, needsSourceReview: false)
    }

    static var usingReport: Article {
        Article(
            id: "using-report", category: .visit,
            title: String(localized: "How to use your MenoMap notes in a visit"),
            summary: String(localized: "Two minutes of prep for a better conversation."),
            body: String(localized: """
            **Before the visit**
            - Add the appointment date in the Visit tab. MenoMap shows how ready your notes are and what would make them stronger.
            - Pick the topics and questions that matter most. Keep it to three or four.
            - Create your notes for the last 30 or 90 days. Check that your medication list is up to date.

            **At the visit**
            - Hand over or show the first page. It's designed to be read in under a minute: counts, averages, the heat calendar and your questions.
            - Start with the question that matters most to you.
            - If your clinician speaks another language, you can create the notes in that language.

            **What the notes are, and aren't**

            They're a summary of what you entered, plus anything you chose to bring in from Apple Health. They aren't a diagnosis or a complete medical record, and any patterns in them are coincidence checks, not proof of cause. Your clinician may ask questions the notes can't answer, and that's normal.

            **After the visit**

            Add any new medication with its start date. In a few weeks, MenoMap can show your entries before and after, which makes your next review easier.
            """),
            sourceName: nil, sourceURL: nil, reviewedAt: nil, needsSourceReview: false)
    }
}
