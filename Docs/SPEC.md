# MenoMap — Claude Code Build Spec (V1)

**App name:** MenoMap  
**Tagline:** See what’s changing. Bring better notes to your clinician.  
**Not:** “Your personal menopause command center.”  
**Platform:** iPhone, iOS 18+, Swift, SwiftUI, SwiftData, StoreKit 2  
**Studio pattern:** GW Labs — one job, local-first, Lock Screen SOS, optional Pro, no medical practice.

This file is the only source of truth. If an earlier draft asked for an AI command center, 12-field daily journals, telehealth, labs, employer SKUs, or ads on health screens, ignore those.

---

## 0. Claude Code execution rules

Read this section before touching files.

### How you work
1. Inspect the repo first. Do not write app code until you have listed: Xcode project path, bundle ID if present, deployment target, existing packages, persistence, StoreKit, design tokens, and anything reusable from sibling GW Labs apps.
2. If the folder is empty, create a new Xcode-ready SwiftUI project structure (`MenoMap.xcodeproj` or an `.xcworkspace` plus sources). Prefer a single iOS app target + a widget extension only when you reach Milestone F.
3. Write an implementation plan to `docs/IMPLEMENTATION_PLAN.md` with the six milestones below. Then implement Milestone A only. Compile. Fix. Then B. Never start D before A–C compile.
4. After each milestone: `xcodebuild` the iOS Simulator destination, run unit tests that exist, fix compile errors before adding features.
5. Do not ask questions that you can decide. Decide and document the decision in `docs/DECISIONS.md`.
6. **Stop and ask** only if the next step would: send health data off-device, embed a secret API key, write to HealthKit, claim a diagnosis, add a third-party analytics SDK that can receive health content, or change the free/paid gate in a way that hides SOS or the 7-day log.
7. No `TODO` for shipped milestone features. If a later milestone is out of scope, ship a protocol + a working in-process fake, not a broken button.
8. No force-unwraps except in tests or `#if DEBUG` sample data.
9. No hardcoded US prices in views. Load StoreKit products; show a skeleton if products fail.
10. No user-facing string literals scattered in views. Use `String Catalog` (`Localizable.xcstrings`) from day one. English only for V1.
11. Do not invent medical citations, URLs, or statistics. Educational copy in V1 is limited to the approved article set in §14. If a source URL is unknown, omit the link and mark the article `needsSourceReview = true`. Do not ship those articles as “reviewed.”
12. Do not add OpenAI, Anthropic, or any LLM SDK in V1. `AskMenoMapService` is a local ranked FAQ + canned answers.
13. Do not add RevenueCat, Firebase, Amplitude, Mixpanel, or AdMob in V1.
14. Do not require an account. No email. No Sign in with Apple in V1.
15. Widgets are Milestone F. Do not block V1 on a widget target if the main app is not compiling.

### Definition of done for V1
A woman can: run a Surge session from the app, save it, finish a 4-question evening check-in in under 30 seconds, see a 7-day heat map, read one pattern after seed data, export a 30-day clinician PDF, and hit a working StoreKit 2 paywall (StoreKit Configuration file in DEBUG). The app never diagnoses.

---

## 1. What this product is

### The job
Get through a hot flash or night sweat **now**, keep a private week of what happened, and hand a clinician a clean 30/90-day packet.

### What V1 is not
- Not a 12-metric research diary
- Not an LLM coach
- Not a period-prediction engine (Apple Health / iOS 27 already owns cycle + peri stage)
- Not a clinic, pharmacy, lab store, or community
- Not a diagnostic or SaMD device

### Legal posture (repeat on onboarding, Learn, PDF footer, Settings)
> MenoMap is a wellness tracker and education tool. It does not diagnose menopause or any other condition, does not prescribe or change treatment, and does not replace care from a qualified clinician. If symptoms worry you, or if you have bleeding after menopause, chest pain, sudden severe headache, one-sided weakness, trouble breathing, or fainting, seek in-person or emergency care.

Post-menopausal bleeding: any vaginal bleeding after menopause (and unexpected bleeding that is not the planned bleed on cyclic HRT) must surface a **non-diagnostic** prompt to contact a clinician. Do not grade likelihood of cancer. Cite the idea, not a fake URL, in-app: bleeding after menopause should be checked. NHS and similar public guidance say even a single episode should be reviewed.

### Core loop
```
SURGE (now) → LOG (10 seconds) → WEEK (heatmap) → PATTERN (correlation) → VISIT (PDF)
```

Not: check-in → AI → command center.

---

## 2. Positioning and store copy (draft)

| Field | V1 text |
|---|---|
| Name | MenoMap |
| Subtitle | Hot flashes, patterns, visit notes |
| Promise | See your symptoms. Notice patterns. Walk into the appointment with notes. |
| Keywords research later | menopause, hot flash, night sweats, perimenopause, HRT log, menopause tracker |

Do not use: cure, treat, reverse, balance hormones, diagnose, AI doctor.

Visual identity: quiet, adult, Apple Health / Oura adjacent. Warm stone background, one ink accent (deep teal or oxidized bronze — pick one and put it in `MenoTheme`). No pink default, no flowers, no sparkles, no “sisterhood” copy.

---

## 3. Architecture

```
MenoMap/
  App/
    MenoMapApp.swift
    AppRootView.swift
  DesignSystem/
    MenoTheme.swift
    Components/   (MenoCard, MenoButton, MetricChip, HeatMap, EmptyState, DisclaimerBanner, PaywallCard)
  Features/
    Onboarding/
    Today/
    Surge/          // Lock Screen-capable session
    CheckIn/
    Log/
    Insights/
    Visit/          // PDF + appointment prep
    Learn/
    Paywall/
    Settings/
  Domain/
    Models/
    Insights/       // pure Swift, unit-tested
    Education/      // static articles
  Data/
    Persistence/    // SwiftData
    Repositories/
    HealthKit/
    SampleData/     // DEBUG only
  Services/
    Subscription/
    Notifications/
    PDF/
    AskMenoMap/     // local FAQ, not a network model
    Commerce/       // protocol only in V1
  Resources/
    Localizable.xcstrings
    StoreKit/MenoMap.storekit
    PrivacyInfo.xcprivacy
```

- MVVM per feature. No god `ContentView`.
- Protocol + implementation for: `CheckInStoreing`, `SurgeStoreing`, `InsightComputing`, `SubscriptionProviding`, `HealthKitReading`, `PDFExporting`, `AskMenoMapAnswering`.
- Dependency injection through a small `AppContainer` created in `MenoMapApp`.
- Target: iOS 18. SwiftData. Observable view models.

---

## 4. Data model (V1 only)

Keep this list short. Do not add models “for later” that have no screen.

```swift
UserProfile          // firstName optional, stage, trackedMetrics, reminderHour, healthKitOn
TrackedMetric        // enum: sleep, energy, mood, hotFlashes, nightSweats, brainFog, stress
DailyCheckIn         // date, optional 0–10 scores for enabled metrics, optional note, alcoholFlag, caffeineFlag
SurgeEvent           // kind: hotFlash | nightSweat, startedAt, durationSec, intensity 1–5, context tags
CycleNote            // optional: bleedingStart, bleedingEnd, flow, spotting, isPostMenopauseFlag, unusualFlag
Medication           // name, doseText, route, scheduleText, startDate, notes  — user-entered only
MedicationDose       // medicationID, takenAt, skipped
TimelineEvent        // type, date, title, note
Appointment          // date, title, topics: [VisitTopic]
Insight              // id, ruleID, title, body, computedAt, windowDays, isPremium
Article              // id, category, title, body, sourceName, sourceURL?, reviewedAt?, needsSourceReview
SubscriptionState    // enum
```

Every persisted record: `id: UUID`, `createdAt`, `updatedAt`.

**Do not persist:** inferred diagnosis, “menopause score,” predicted next period, AI chat transcripts with health dumps.

HealthKit in V1 is **read-only**, optional: sleep analysis (time asleep if available), and nothing else until Milestone C is stable. Never write to HealthKit. Never say a HealthKit number “proves” a cause.

---

## 5. Privacy

- Default: all data on device. SwiftData local store.
- No account.
- Settings → Privacy: what is stored (plain language), Export JSON, Delete All (two-step confirm).
- Analytics V1: **none**, or only `os_log` debug. If you add anything, it cannot include notes, med names, scores, or free text.
- `PrivacyInfo.xcprivacy` required.
- Privacy Nutrition Label: Health data used for app functionality, not linked to identity, not used for tracking.
- `Ask MenoMap` never uploads logs. It only matches the question to local articles.

---

## 6. Information architecture

**Four tabs. Not five.**

| Tab | Job |
|---|---|
| **Today** | Greeting, Surge button, Check in, 7-day heat map, latest pattern, Visit shortcut |
| **Week** | Charts 7 days (free) / 30–90 (Pro), patterns list, timeline |
| **Visit** | Appointment prep checklist + Generate report |
| **You** | Profile, tracked metrics, meds, Learn library, subscription, privacy, legal |

Learn is a section inside You in V1, not a fifth tab. Adding a fifth tab for 8 articles is noise.

---

## 7. Onboarding (6 screens, skippable)

Keep copy short. Every screen can Skip except legal.

1. **Promise** — “See what’s changing.” Sub: “Log a surge in one tap. Spot patterns. Print notes for your clinician.” Primary: Get Started. No “Already have an account.”
2. **Why you’re here** — multi-select. Options: noticing changes / symptoms / peri / menopause / post / tracking treatment / visit prep / not sure.
3. **What to show on Today** — multi-select metrics. Default on: hot flashes, night sweats, sleep. Others off until chosen. Include: mood, energy, brain fog, stress. Do not dump 16 symptoms here.
4. **Stage (optional)** — peri / menopause / post / not sure / prefer not to say. If post: one sentence that any bleeding should be checked by a clinician.
5. **Apple Health** — sleep only. Connect or Skip. Explain read-only.
6. **Privacy + disclaimer** — the legal paragraph in §1. Link placeholders: `https://gwlabs.app/privacy` and `https://gwlabs.app/terms` (or local markdown pages). Continue.

Then immediately start **first Surge or first Check-in** (user picks). Do not show the paywall in session 1.

Do not ask: sexuality, partner, children, uterus, income. If they have no periods, cycle tracking stays hidden until they enable it in You.

---

## 8. Today

Top: date. Optional first name if they typed one.

**Primary control (largest):** `I’m having a surge` → Surge session (hot flash default; toggle night sweat).

**Secondary:** `Evening check-in` (or Morning if they chose that later; V1 default is one evening check-in).

**Heat map:** last 7 days, intensity of surges + sleep score if present. Color + number, not color alone.

**Pattern slot:** one Insight or empty state: “Patterns need about two weeks of check-ins.”

**Quick actions (max four):** Log surge after the fact · Check in · Add medication · Visit notes.

No “Ask MenoMap” hero button on Today.

---

## 9. Surge session (the differentiator)

This is CalmAnchor SOS, renamed.

Flow:
1. Kind: Hot flash / Night sweat
2. Big timer, dim UI (especially night), haptic once
3. Copy: “These often crest and ease within a couple of minutes. This is not medical treatment.”
4. Optional 4-count breathe coach (same simple box as CalmAnchor: in 4, hold 4, out 4). Skip allowed.
5. End: intensity 1–5, duration auto from timer (editable), optional tags: alcohol / heat / stress / exercise / caffeine / unknown
6. Save. Back to Today. Widget refresh if widget exists.

Also support **log after the fact** (already over): time, duration buckets (`<1m`, `1–5`, `5–15`, `15+`), intensity, tags.

App Intent: `StartSurgeIntent` so Siri / Control Center / Action Button can start it. Implement in Milestone C if time; otherwise stub the intent and leave a note in DECISIONS.

---

## 10. Daily check-in (≤30 seconds)

Default questions (only enabled metrics):

- Sleep 0–10  
- Hot flashes today 0–10 (in addition to Surge events; this is a daily rollup)  
- Mood 0–10  
- Energy 0–10  

Optional extras the user can enable: stress, brain fog, night sweats rollup.

Always optional:  
- Alcohol last evening? Y/N  
- Caffeine later than usual? Y/N  
- One-line note  

No sliders for 8 domains. No required fields. Done button always enabled.

Customization: You → Tracked metrics. Changing metrics must not delete old logs.

---

## 11. Cycle (optional, hidden by default)

You → Cycle. Off unless they enable it.

Fields: start, end, flow light/medium/heavy, spotting, note.

If profile stage is post-menopause **or** they flag “I no longer have periods,” logging new bleeding shows a full-width banner:

> Bleeding after menopause — even once, even light — should be checked by a clinician. MenoMap cannot tell you why it happened.

Do not implement fertile-window or next-period prediction.

---

## 12. Medications / HRT

User-typed name + dose text + how they take it + start date.

Category chips (organizational only): estrogen · progestogen · combined · vaginal estrogen · non-hormonal · supplement · other.

Reminders: optional local notification, user-set time. Missed dose is a log, not a lecture.

**Forbidden copy:** start this, stop that, increase dose, “your HRT is working,” “you need progesterone.”

Insights may say: “You logged fewer intense surges in the 14 days after you added [medication name they typed]. That is a coincidence check, not proof the medicine is the reason.”

---

## 13. Insights engine (local, rule-based)

Pure Swift in `Domain/Insights`. No ML. No cloud.

Rules, each with `minSamples`:

| ID | Needs | Window | Copy shape |
|---|---|---|---|
| `sleep_after_3plus_surges` | surge count that night + sleep score | 14 days | “On N nights with 3+ surges, average sleep score was X vs Y on other nights.” |
| `alcohol_then_sweats` | alcohol flag + night sweat / surge | 14 days | “On N evenings marked alcohol, night sweats were logged M times.” |
| `severity_change` | surge intensity | 30 vs prior 30 | “Average surge intensity was A in the last 30 days vs B in the 30 before.” |
| `missed_doses_note` | skipped doses + surges | 14 | Only if both exist. Correlation wording only. |

Do not emit a rule with n < 7 paired days. Prefer 14.

Tone: “Your entries show…” never “This means you have…” never “Hot flashes caused…”

Premium gate: 7-day raw charts are free. Rule-based patterns and 30/90-day charts are Pro. Empty state still explains what will appear.

Unit test every rule with fixtures (see §19).

---

## 14. Learn (static, small)

Ship **eight** articles max. Each has: title, 300–600 words you write as general education, source *name* only if you are sure, `needsSourceReview = true` unless the operator later flips it.

Approved topics:
1. What perimenopause and menopause refer to (definitions, not a quiz that “diagnoses” the user)
2. Vasomotor symptoms (hot flashes / night sweats) — common, variable, not a diagnosis of cause
3. Sleep disruption — many causes exist
4. Why a symptom diary can help a visit
5. Hormone therapy is a clinician decision (no product names as recommendations)
6. Non-hormonal approaches exist; discuss with a clinician
7. Bleeding after menopause should be evaluated
8. How to use this app’s report in a visit

`Ask MenoMap` in V1: search bar over these 8 titles + 20 FAQ strings mapped to the same articles. Examples: “Why 3am waking?”, “Is brain fog common?”, “What do I bring to the doctor?”, “Can I ask about HRT?”

If no match: “MenoMap doesn’t know that yet. If you are worried, contact a clinician. If this feels urgent, use local emergency services.”

No network. No streaming tokens.

---

## 15. Visit: appointment prep + PDF

### Prep
User picks topics: hot flashes, night sweats, sleep, mood, bleeding, treatment I already take, vaginal/urinary, weight, other.

Generate a checklist of **questions they may ask**, not answers:

- Which of these is most disruptive for me?
- When did this start, and has it changed?
- What should I watch for that means I should call?
- How do my current medications fit this picture?

### PDF (`Create my notes`)
Windows: 7 / 30 / 90 days.

Contains:
- Date generated, app name, disclaimer box
- Counts: surges, average intensity, night sweats
- Check-in averages for enabled metrics
- Sleep from logs (and HealthKit sleep minutes if present, labeled “from Apple Health”)
- Medications the user entered
- Cycle notes if any, including the bleeding-after-menopause banner text if that flag fired
- Up to 3 insights that fired in the window
- User’s selected questions
- Footer: “Entered by the user. Not a diagnosis. Not a complete medical record.”

PDFKit. Preview → Share sheet. Pro-gated. Free users see a watermarked 7-day preview of counts only + paywall.

---

## 16. Monetization

### Products (StoreKit 2)
Use a `.storekit` file. Product IDs (change only in one config plist):

- `menomap.pro.monthly`
- `menomap.pro.yearly`
- `menomap.pro.lifetime`

**List prices to configure in App Store Connect** (do not paint these as the only display string):

- Monthly $9.99  
- Yearly $49.99 (default selected, badge “Best value”)  
- Lifetime $79.99  

No weekly in V1.

`SubscriptionManager`: load products, purchase, restore, current entitlements, listen to `Transaction.updates`. App usable if StoreKit is down (cached entitlement; otherwise Free).

### Free
- Surge + after-the-fact log  
- Daily check-in  
- 7-day heat map and 7-day simple averages  
- 8 Learn articles + local Ask  
- Med list (no reminder stacking limits needed)  
- Privacy / delete / export JSON  

### Pro
- Patterns (rule engine output)  
- 30/90/365 charts  
- Clinician PDF  
- Appointment prep generator  
- Dose reminders  
- Optional: JSON export of full history is actually Free (privacy). Keep export Free.

### Paywall
Headline: “See the month, not just the day.”  
Benefits: longer charts, patterns, visit PDF, reminders.  
Close button visible. No countdown. No “your data will be deleted.” Show after: third check-in, or first tap of PDF, or first Patterns row — not after install.

### Ads
None in V1. None ever on Surge, check-in, meds, Learn, PDF.

### Commerce / referrals / employer
Create empty protocols:

```swift
protocol CommerceRecommending { func items(for context: CommerceContext) -> [CommerceItem] }
protocol CareReferralRouting { func options() -> [CareReferral] }
```

Implementations return `[]`. No UI unless count > 0. Do not add affiliate URLs.

---

## 17. Notifications

Default **off** except a single optional evening check-in if they opt in during onboarding (default: off).

Types: evening check-in, appointment the morning of, “you have 30 days of logs — generate notes?” (max once).

No streak shame. No “you’re falling behind.”

---

## 18. Design and accessibility

- `MenoTheme`: background, surface, ink, accent, danger (for bleeding banner only), radius 16, spacing 8-pt grid
- Dynamic Type, VoiceOver labels on sliders and heat map cells
- Reduce Motion: skip breathe animation
- Contrast: WCAG-minded; don’t encode severity with red/green only
- Dark mode required
- Min hit target 44pt
- Surge night mode: dim, large type

---

## 19. Tests

Unit tests (required):
- Insight rules with insufficient data → no insight
- Insight rules with fixture 14-day series → expected copy numbers
- Check-in customization does not drop historical scores
- PDF section builder includes disclaimer
- Post-menopause bleeding flag trips banner
- `AskMenoMap` unknown query → safe fallback
- Entitlement: lifetime OR active sub → Pro; expired → Free
- Date windows (7/30/90) use calendar days not rolling hours only — pick calendar and test DST

UI tests if time after Milestone E: onboarding skip path, check-in save, paywall close.

DEBUG sample store: 30 days of fictional data behind a Settings switch “Load demo data.” Off in Release. Never preload demo in production builds.

---

## 20. Safety copy bank (use these; do not freelance clinical advice)

**Chest pain / fainting / neuro:** “This can be an emergency. Contact emergency services. MenoMap cannot assess this.”

**Palpitations logged:** “Heart sensations have many causes. If they are new, severe, or come with chest pain, shortness of breath, or fainting, seek care now.”

**Bleeding after menopause:** see §11.

**Medication questions:** “MenoMap cannot tell you to start, stop, or change a medicine. Bring your list to a clinician.”

**“Do I have menopause?”:** “Only a clinician can evaluate that. What MenoMap can do is show what you logged.”

---

## 21. Explicitly out of V1

Do not build: social, DMs, forums, clinician marketplace, telehealth, labs, insurance, wearables beyond HealthKit sleep read, cycle prediction, gamification/XP, AI backend, widgets until F, Sign in with Apple, iCloud sync, Android, Watch app (Watch can wait; App Intent is enough), ads, affiliate SKUs, employer admin.

---

## 22. Milestones

Ship in this order. Each milestone ends with a green `xcodebuild` and a short note in `docs/IMPLEMENTATION_PLAN.md`.

### Milestone A — Skeleton
- Project, tabs, theme, String Catalog, SwiftData stack, `AppContainer`
- Empty Today / Week / Visit / You
- Disclaimer component
- Settings shell: privacy text, delete all (works)

### Milestone B — Capture
- Onboarding as specified
- Surge live + after-the-fact
- Check-in with customizable metrics
- Today heat map (7 day)
- Med list CRUD
- Optional cycle + bleeding banner

### Milestone C — Understand + Health
- Insight engine + tests
- Week charts 7/30/90 (30/90 show lock if Free)
- HealthKit sleep read, denied-path works
- Timeline of surges + med start events + check-ins

### Milestone D — Visit
- Appointment prep
- PDF generate / preview / share
- Free watermarked tease + paywall hook

### Milestone E — StoreKit + Learn
- `.storekit` config, SubscriptionManager, paywall, restore
- Learn 8 articles
- Local Ask MenoMap
- Notifications opt-in
- Export JSON + delete

### Milestone F — Polish only if E is stable
- `StartSurgeIntent`
- Small + medium widgets (today intensity / 7-day)
- Accessibility pass
- App Store screenshots copy in `docs/ASC_CHECKLIST.md`

Do not start F if E entitlements are flaky.

---

## 23. StoreKit, HealthKit, Info.plist

**Signing:** leave DEVELOPMENT_TEAM empty if unknown; use automatic signing placeholders.

**HealthKit usage string:**  
“MenoMap reads sleep data you choose to share so it can sit next to your night-sweat log. It does not write to Apple Health.”

**Background modes:** none required for V1 unless notifications need the standard permission only.

**StoreKit:** add `MenoMap.storekit` to the scheme.

**ATS:** default. No arbitrary loads.

**No embedded secrets.**

---

## 24. Final report Claude must write

When Milestone E compiles, write `docs/SHIPPED.md`:

1. What works  
2. File map  
3. How to run (scheme, simulator, storekit file)  
4. HealthKit notes  
5. Product IDs  
6. What is stubbed  
7. Known limitations  
8. App Store checklist (privacy policy URL, disclaimer, HealthKit, subscriptions EULA, screenshots)  
9. What must never be claimed in store copy  

---

## 25. First action

1. List the repo.  
2. Write `docs/IMPLEMENTATION_PLAN.md` and `docs/DECISIONS.md`.  
3. Implement Milestone A only.  
4. Compile.  
5. Stop and continue to B without asking.
