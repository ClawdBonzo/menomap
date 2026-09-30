# /menomap.html — the MenoMap app page

Final copy. Build it with the same template, classes, chrome (gwl-header / gwl-footer), section order and sticky
download bar as the live `https://gwlabs.app/wishlock.html`. Only the content below changes.

## Head

- `<title>`: `MenoMap: Menopause Tracker App for iPhone | GW Labs`
- `meta description`, `og:description`, `twitter:description`:
  `MenoMap is a menopause tracker for iPhone and Apple Watch: log hot flashes and night sweats in one tap, see your patterns and bring clear notes to your doctor.`
- `og:title`, `twitter:title`: same as `<title>`
- `og:image`, `twitter:image`: `screens/01-today.webp` (uploaded), `og:image:alt`: the alt text of screenshot 1 below
- `meta name="apple-itunes-app" content="app-id=6817484445"`
- `apple-touch-icon`: `icon-180.png` (uploaded)
- canonical and og:url: let the host inject them as for the other app pages; the canonical URL is `https://gwlabs.app/menomap.html`

App Store link used by every download button on this page:
`https://apps.apple.com/app/apple-store/id6817484445?pt=117201882&ct=gw-menomap&mt=8`

## Hero

Eyebrow: **One tap. Clear notes.**

H1: **MenoMap: Menopause Tracker**

Intro:
MenoMap is a menopause tracker for iPhone and Apple Watch. When a hot flash or night sweat starts, tap once from your
Lock Screen, Control Center, the Action Button or your watch: MenoMap times it, breathes with you if you want, and saves
it. A 30-second evening check-in, a heat map of your days and patterns found in your own entries turn a blurry month into
something you can see. Before an appointment, MenoMap makes a one-page summary for your clinician, in the language they
speak. No account, no ads, and your health data stays on your iPhone.

[App Store badge]

## Gallery (H2: **Built for the moment itself**)

Nine screenshots, in this order, 645 × 1401, lazy-loaded after the first. Use these files and this alt text exactly.

| File | Alt text |
|---|---|
| `screens/01-today.webp` | MenoMap Today screen with the one-tap "I'm having a surge" button, the evening check-in and the last 7 days |
| `screens/02-night-watch.webp` | Night Watch on the iPhone Lock Screen at 2:47 AM: a dim night-sweat button and a running surge timer |
| `screens/03-heat-map.webp` | MenoMap heat map of the last 30 days with the surge gauge, daily counts and the surge clock |
| `screens/04-patterns.webp` | MenoMap patterns found in the user's own entries, each marked as a coincidence check, not proof |
| `screens/05-notes.webp` | The one-page clinician notes PDF with surge counts, the heat calendar and the user's questions |
| `screens/06-apple-health.webp` | Connect Apple Health screen: what MenoMap reads and what it writes back |
| `screens/07-apple-watch.webp` | MenoMap on Apple Watch: the Night sweat button and a strength rating set with the Digital Crown |
| `screens/08-experiment.webp` | A two-week experiment card: 26 night surges in the 14 days before a cooler bedroom, 27 during |
| `screens/09-privacy.webp` | MenoMap Privacy screen: on this iPhone only, Apple Health, no account and no cloud, no health analytics |

## How it works (H2)

1. **Tap when it starts.** One tap from the Lock Screen, Control Center, the Action Button, Siri or Apple Watch starts a
   surge timer (a surge is MenoMap's word for one hot flash or night sweat). Tap again when it's over and rate how
   strong it was. Missed one? Log it afterwards in a few seconds.
2. **Check in each evening.** Four quick questions about sleep, mood and energy, in under 30 seconds.
3. **Walk in with notes.** Add your appointment and MenoMap shows how ready your notes are. Pick your questions, then
   create a clean one-page PDF of the last 30 or 90 days for your clinician.

## Features (H2)

- One-tap surge button on the Lock Screen, in Control Center, on the Action Button, with Siri and on Apple Watch
- Night Watch: a dim, one-tap night-sweat button on your Lock Screen from bedtime until morning
- Optional 4-4-4 breathing while a surge is timed, and Double Tap on Apple Watch to end it
- A 30-second evening check-in for sleep, mood and energy
- Heat map of your days, a surge clock showing when surges cluster, and your most-tagged triggers
- Patterns in your own entries, like how your nights look after an evening with alcohol, always shown as a coincidence
  check, never as a cause
- Two-week experiments: try one change, like a cooler bedroom, and compare your own before and during
- Works with Apple Health: reads the symptoms (and, on iOS 27, the menopause stage) you've logged there, and saves every
  surge you log back to Health
- Clinician notes: a one-page PDF of 30 or 90 days, A4 or Letter, in any of MenoMap's 34 languages
- Medication list with start dates, so your notes show what changed and when, plus optional dose reminders
- A monthly Heat Report and a Weekly Wrap to share, plus stickers and "heads-up" cards for Messages
- Eight plain-language articles, checked against NHS and The Menopause Society guidance, with a question box that answers
  on your iPhone
- Export everything as a readable file, or delete it all in one step

CTA line under the list: **Log your first surge in one tap.** [App Store badge]

## Who it's for (H2)

People in perimenopause, menopause or post-menopause who want to understand their hot flashes and night sweats, anyone
getting ready for a menopause appointment or a hormone therapy review, people trying a change (a cooler bedroom, less
alcohol, a new medicine their clinician prescribed) and wanting to see what their own entries show, and anyone who
wants a menopause symptom diary that's fast enough to use in the moment. MenoMap is designed for readers in their 40s,
50s and 60s: large type, full Dynamic Type and VoiceOver.

## Privacy (H2)

MenoMap has no account and no sign-up. Your surges, check-ins, medications, notes and appointments are stored on your
iPhone, not on a MenoMap server, and nothing is stored in iCloud by the app. If you connect Apple Health, MenoMap reads
only the types you allow and writes only the surges and bleeding you log; Apple Health manages that data. There are no
ads and no analytics tools. Purchases are handled by Apple, and MenoMap uses RevenueCat to record them under an
anonymous ID, which never receives any health data. Share cards and PDFs are made on your iPhone and leave it only if
you send them. Read the full [MenoMap privacy policy](/menomap/privacy).

## For clinicians (H2)

Patients can bring a one-page summary of what they logged: surge counts and strength, time of day, a heat calendar,
evening check-in averages, medications with start dates, and their questions, in your language.
[See what the notes contain and how to read them](/menomap/clinicians).

## Languages (H2)

34 languages: English (US), English (UK), Arabic, Chinese (Simplified), Chinese (Traditional), Croatian, Czech, Danish,
Dutch, Finnish, French, German, Greek, Hebrew, Hindi, Hungarian, Indonesian, Italian, Japanese, Korean, Malay,
Norwegian, Polish, Portuguese (Brazil), Portuguese (Portugal), Romanian, Slovak, Spanish (Spain), Spanish (Latin
America), Swedish, Thai, Turkish, Ukrainian and Vietnamese.

## Price (H2)

MenoMap is free to download, with the one-tap surge button everywhere (including Night Watch and Apple Watch), the
evening check-in, the last 7 days of your heat map and stats, Apple Health, the articles, your medication list, the
monthly Heat Report cover, one pattern revealed each week, and export and delete. There are no ads, on any plan.
MenoMap Pro adds 30, 90 and 365-day history and stats, every pattern, two-week experiments, the full Heat Report,
clinician notes as a PDF, appointment prep, medication reminders and share cards without the watermark:

- Monthly $9.99
- Yearly $49.99 (7-day free trial for eligible new subscribers)
- Lifetime $99.99, one-time purchase

Yearly and Lifetime include Family Sharing. Just need notes for one appointment? A single **Visit Report** ($4.99,
one-time) unlocks one full PDF of up to 90 days, with no subscription.

Prices are in US dollars and vary by country. Subscriptions renew automatically unless cancelled at least 24 hours
before the end of the period, and you can manage or cancel them in your Apple Account settings.

MenoMap is a wellness tracker and education tool. It does not diagnose menopause or any other condition, does not
prescribe or change treatment, and does not replace care from a qualified clinician. Bleeding after menopause, chest
pain, a sudden severe headache, one-sided weakness, trouble breathing or fainting need in-person or emergency care.

## Frequently asked questions (H2, also the FAQPage JSON-LD, same wording)

**What is a "surge"?**
MenoMap's word for one hot flash or night sweat. Tap once when it starts and once when it ends, and MenoMap saves how
long it lasted, the time of day and how strong it felt (1 to 5).

**What is Night Watch?**
A dim Lock Screen button for night sweats that stays from your bedtime until morning, so logging one at 3 AM takes a
single tap without unlocking or lighting up the room. It's free.

**Does MenoMap work with Apple Health?**
Yes, if you choose to connect it. MenoMap reads the symptoms you've logged in Health (and, on iOS 27, your menopause
stage), so your history shows up on day one, and it saves every hot flash and night sweat you log back to Health.

**What goes in the clinician notes?**
A one-page PDF of the last 30 or 90 days: surge counts, strength and time of day, a heat calendar, evening check-in
averages, sleep from Apple Health if connected, your medications with start dates, patterns, and the questions you want
to ask. You can create it in any of MenoMap's 34 languages, on A4 or Letter paper.

**Can MenoMap tell me if I'm in perimenopause?**
No. MenoMap doesn't diagnose anything. It keeps an honest record of what you notice so you and your clinician can look at
the same picture. Patterns are coincidence checks in your own entries, never proof of a cause.

**Do I need an account? Where is my data?**
No account is needed. Everything you log stays on your iPhone and in your normal encrypted iPhone backup. MenoMap never
uploads your health data, and there are no ads or analytics.

**Is MenoMap free?**
Yes, the one-tap logging, Night Watch, Apple Watch, the check-in and the last 7 days are free, with no ads. MenoMap Pro is
available monthly, yearly (with a 7-day free trial for eligible new subscribers) or as a one-time lifetime purchase, and
a single Visit Report is available for one appointment.

**I have a code from my clinic. How do I use it?**
Open MenoMap, go to You, and tap "Redeem a clinic or friend code". Clinic codes give one month of MenoMap Pro free.

**Which devices and languages does it support?**
iPhone with iOS 18 or later, and optionally Apple Watch with watchOS 11 or later. Reading your menopause stage from
Apple Health needs iOS 27. MenoMap is available in 34 languages.

## Closing CTA

H2: **Ready for one-tap logging?** [App Store badge]
Already using MenoMap? [Leave a review on the App Store](https://apps.apple.com/app/id6817484445?action=write-review)
MenoMap is made by GW Labs.

## JSON-LD (same structure as /wishlock.html)

- `MobileApplication`: name "MenoMap: Menopause Tracker", applicationCategory "HealthApplication",
  operatingSystem "iOS 18.0 or later", description = the meta description, image = `icon-1024.png` URL,
  inLanguage = the 34 codes (en, en-GB, ar, zh-Hans, zh-Hant, hr, cs, da, nl, fi, fr, de, el, he, hi, hu, id, it, ja, ko,
  ms, nb, pl, pt-BR, pt-PT, ro, sk, es, es-419, sv, th, tr, uk, vi), author and publisher = the GW Labs Organization.
  Add `downloadUrl` and `offers` (price "0", USD) **only once the app is live** (see the prompt, step 6).
- `FAQPage` with the nine questions above, same wording.
- `BreadcrumbList`: GW Labs (https://gwlabs.app/) → MenoMap (https://gwlabs.app/menomap.html).
