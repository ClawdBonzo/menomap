# MenoMap — Spec Additions (the "10/10" plan)

**Status:** Draft for Rob's review, 2026-09-29. Nothing built yet.
**Precedence:** This file overrides `Docs/SPEC.md` (the original build spec) wherever they conflict. Everything in SPEC.md not touched here still applies: legal posture, no diagnosis, the safety copy bank, the insight tone rules, and on-device storage.
**Approved by Rob (2026-09-29):** Apple Health read + write; Watch app, Live Activity and Control in V1; a wry voice for share cards; a $4.99 Visit Report and $99.99 lifetime; RevenueCat observer mode; no ads ever. Plus: "make this a 10/10" and "all countries that are a good fit." Market details are in `Docs/MARKETS.md`.

---

## 1. Why the original spec was a 6 and what makes it a 10

| Problem in SPEC.md | Fix |
|---|---|
| iOS 27 Health (shipped Sept 2026) now does stage, symptom logging, the bleeding-after-menopause alert and education, all free. | **Build on Apple Health instead of competing with it.** Read the stage and past symptoms from Health on day 1, and write every surge back. MenoMap becomes the fast way to log and the smart way to read what Health already holds. |
| The Surge button, the one real differentiator, sat behind the app icon, and widgets were deferred to the last milestone. | The Surge button can be started from the **Lock Screen, Control Center, the Action Button, Siri, the Watch, the Dynamic Island and StandBy**, all in V1. |
| It looked like Apple Health, which is free. | A distinct identity: editorial serif headlines, warm stone ground, an **ember heat scale** for data and a **cool teal** for relief. Stats get the Wrapped treatment, like WishLock 1.1 and Places I've Had Sex. |
| There was no reason to come back except a notification that is off by default. | An **appointment countdown**, a pre-filled **morning card**, two-week **experiments** and a monthly **Heat Report**. |
| There was no reason to tell anyone. | **Share cards**, **"Tell my person"**, a **PDF that advertises itself** to clinicians, and a **friend pass** offer code. |
| Pro sold dose reminders, which Apple's Medications app does for free. | Pro sells what only MenoMap has: patterns, experiments, long-range stats, the clinician PDF and the Heat Report. |
| English only. | About 32 languages at launch, with regional terms (UK "hot flush", Spain "sofocos", Mexico "bochornos"), a safety-copy audit, local emergency numbers, A4 or Letter paper size, and a PDF language picker. |

---

## 2. Platform and project

- **iOS 18.0 minimum** (reach: this audience upgrades phones slowly). iOS 27-only Health types (`MenopausalState`, `BleedingAfterMenopause`) are wrapped in `if #available(iOS 27, *)` checks.
- **watchOS 11 minimum.** Xcode 27.0 / SDK 27.0 is installed.
- **XcodeGen** project (`project.yml`), same as WishLock.
- `~/Desktop/MenoMap` currently sits inside the home-folder git repo. Run `git init` in the folder so it gets its own repo like the sibling apps. The repo stays private because `Docs/` holds strategy.
- Bundle IDs: `app.gwlabs.menomap`, `app.gwlabs.menomap.widgets`, `app.gwlabs.menomap.watchkitapp`. App Group: `group.app.gwlabs.menomap`.
- Targets:
  1. **MenoMap** (iOS app)
  2. **MenoMapWidgets** (widgets, Live Activity, Controls)
  3. **MenoMapWatch** (watchOS app and complications)
  4. **MenoCore** (local Swift package: models, insight engine, Health mapping, share-card renderer, strings)
  5. **MenoCoreTests**
- SwiftData store at an **explicit URL in the app sandbox**. The WishLock gotcha: an App Group entitlement silently moves the default store into the group container. Widgets read a small snapshot JSON that the app writes to the App Group.
- Day keys use a **Gregorian calendar** regardless of the device calendar (another WishLock gotcha).
- **Reuse** from `~/Desktop/CalmAnchor-Anxiety`: `PanicBreathingAttributes` / `PanicBreathingLiveActivity` become the Surge Live Activity, and `WidgetDataStore` becomes the snapshot. From WishLock: the localization pipeline and tools, the screenshot compositor, and the fastlane lanes.
- Folder is `Docs/` (the sibling-project convention), not `docs/`.

---

## 3. Apple Health (read + write)

All symptom types below were verified in the installed iOS 27 SDK headers.

**Write** (only what the user logged; edits and deletes are mirrored):
| MenoMap | HealthKit type | Value |
|---|---|---|
| Surge: hot flash | `hotFlashes` | severity: intensity 1–2 → mild, 3–4 → moderate, 5 → severe |
| Surge: night sweat | `nightSweats` | same mapping |
| Bleeding log (post-menopause profile) | `bleedingAfterMenopause` (iOS 27) | flow value |
| Cycle bleeding (otherwise) | `menstrualFlow` | flow value |
| Check-in extras, if enabled | `sleepChanges`, `moodChanges`, `memoryLapse` (brain fog), `fatigue` | severity from the 0–10 score, bucketed |

Every written sample carries MenoMap's own event ID in its metadata. Edits delete and rewrite the sample; deletes delete it. This satisfies Apple's rule 5.1.3(ii) against inaccurate Health data.

**Read:**
- `menopausalState` (iOS 27) sets the stage and skips the onboarding stage screen when present.
- Symptom history (the types above plus `rapidPoundingOrFlutteringHeartbeat`, `vaginalDryness`, `bladderIncontinence`, `headache`, `chills`) is imported for the **last 90 days at onboarding**, so the heat map and first patterns can appear on day 1.
- `sleepAnalysis`, and `appleSleepingWristTemperature` shown next to night sweats.
- Resting heart rate is read-only context in the PDF, optional.

**Dedupe:** skip samples whose source is MenoMap (checked by source bundle ID and the event-ID metadata). Store an `HKLink(sampleUUID ↔ eventID)` table. Background delivery through an `HKObserverQuery` keeps imports fresh.

**Copy rule:** anything from Health is labeled "from Apple Health". Nothing ever says a number "shows", "means" or "proves" a cause. Wrist temperature is context, never detection. Apple's rule 1.4.1 forbids temperature claims from sensors.

Permission is asked in onboarding with the value up front: "Bring in what you've already logged in Health." A denied or partial grant works everywhere.

---

## 4. The Surge button, everywhere (V1)

| Surface | Behavior |
|---|---|
| App | Giant "I'm having a surge" button; hot flash or night sweat toggle |
| **Live Activity / Dynamic Island** | Timer and breathing phase; buttons for **End** and **Night sweat** (App Intents inside the Live Activity) |
| **Control Center + Lock Screen control** (iOS 18 `ControlWidget`) | One tap starts a surge; the Live Activity appears at once |
| **Action Button** | Through `StartSurgeIntent`; onboarding shows how to assign it |
| **Siri / Shortcuts** | Localized phrases, e.g. "Log a hot flash in MenoMap" |
| **Interactive widget** (small) | Surge button plus today's count |
| **StandBy / night** | Dim, red-shifted, large type; no white flash at 3am |
| **Apple Watch** | Complication or Smart Stack tap → haptic box breathing on the wrist → **Double Tap to end** → rate 1–5 with the Digital Crown. The phone never lights up. |
| After the fact | Duration buckets, intensity, tags (unchanged from the spec) |

The Watch sends events to the phone through `WatchConnectivity` (`transferUserInfo`, which guarantees delivery). **The phone is the single source of truth and the only writer to Health**, which avoids duplicates. The Watch keeps a small queue in case the phone is unreachable.

Surge copy stays as specified ("often crest and ease… not medical treatment").

---

## 5. Reasons to come back (no streak shame)

1. **Appointment countdown** (the core loop). Onboarding asks: "Seeing a clinician soon? (optional)". Today and a widget show: "Dr. Patel in 9 days · notes 70% ready". The readiness meter covers days logged, surges, check-ins, meds entered and questions picked. On the morning of the appointment: "Your notes are ready." This replaces the streak as the reason to log daily, because it's tied to a real event.
2. **Morning card.** Pre-filled from overnight Health and Watch data, confirmed with one tap: "Last night: 2 night sweats · 6h 12m asleep · wrist temp +0.4° from Apple Health. Right?" That turns logging into confirming.
3. **Experiments** (Pro), two weeks each, run and judged on the user's own entries:
   - No alcohol after 7pm
   - No caffeine after noon
   - Cooler bedroom
   - Evening breathing
   - A custom experiment

   The result card says: "Your entries: 11 night sweats in the 14 days before, 6 during. That's what you logged, not proof of cause."
4. **Heat Report** (monthly, on the 1st). A story-format recap: count, average length, peak hour, calmest week, top tag, and how the month compares with last month. Free users get the cover card; Pro users get the full story.
5. **Notifications** (all opt-in):
   - Evening check-in
   - Appointment T-7, T-1 and the morning of
   - Heat Report ready
   - Experiment finished

   No guilt copy.

---

## 6. Stats and visual identity (Wrapped-grade)

A `Docs/MenoMap_Visual_Identity.md` is written first (Milestone A). Direction:
- **Ground:** warm stone (light) and warm charcoal (dark).
- **Ink:** deep teal, used for brand, buttons, breathing and relief.
- **Heat scale:** one ember hue in stepped opacity, **for data only** (heat map, surge clock, gauges). Intensity is always labeled with the number too, never color alone.
- **Danger red** is used only for the bleeding banner.
- **Type:** New York serif for headlines, SF Pro for everything else. Defaults sized for readers 45–60: Surge button text around 34pt, body at Large or above, all Dynamic Type sizes including the accessibility sizes, and a WCAG AA contrast floor.
- No pink default, no flowers, no sparkles, no confetti (as in the spec).

**Stats screen** (inside Week):
- **Thermostat gauge:** this week vs last week.
- **Heat calendar:** month grid, one hue.
- **Surge clock:** 24-hour radial chart with the peak hour called out ("Your 3:12am club").
- **Trigger podium:** the top three tags by share of surges, with correlation copy.
- **Records:** longest, shortest, calmest day, longest calm stretch.
- **Treatment timeline:** medication start marked on the trend, with coincidence-check wording.

Pro cards appear blurred with one free reveal per week (the WishLock pattern). Every animation has a Reduce Motion fallback.

**Voice setting** (You → Voice): **Wry** or **Straight**. It changes only the stats, share-card and empty-state copy. The PDF, safety copy, legal text, Learn and onboarding legal are always Straight. The default is Wry in locales where menopause humor is mainstream (en, de, nl, the Nordics, es, pt, it, fr, pl) and Straight elsewhere (ja, ko, zh, ar, he, th, vi, id, ms, hi, tr); translators confirm the default per locale.

Wry examples (English): "14 personal summers this week." "Peak hour: 3:12am. Rude." "Longest calm stretch: 4 days. Frame it."

---

## 7. Sharing and growth

1. **Share cards** (9:16 story, 1:1 square), for: a surge week, the Heat Report, an experiment result, a calm-streak record.
   - **Numbers only, opt-in, rendered on device.** Medication names are off by default. Nothing leaves the phone except through the user's own share sheet.
   - A small "MenoMap" wordmark, plus an optional App Store QR code (on by default, can be turned off).
2. **"Tell my person."** Pre-written, localized heads-up messages sent through the share sheet or Messages:
   - "Night sweat. Cracking the window."
   - "Hot flash, give me 3 minutes."
   - "Rough night, I'll be slow this morning."

   A custom message can be added. Apple's rule 5.1.3(ii) **forbids storing health information in iCloud**, so there is no live synced partner status and no CloudKit. Messages is the transport.
3. **The PDF sells itself.** It's genuinely beautiful: a heat calendar, the surge clock, trends, a medication timeline and the user's questions. A quiet footer reads "Made with MenoMap · gwlabs.app/menomap" with a QR code.
   - A **clinician page** at gwlabs.app/menomap/clinicians has a printable patient handout, so clinicians become the channel.
   - **PDF language picker** separate from the app language (for users whose clinician speaks another language).
   - **Paper size** follows the region: Letter for US, CA, MX and PH; A4 elsewhere.
4. **Friend pass.** A custom App Store offer code ("30 days of Pro for a friend") behind "Share MenoMap" in You. Apple offer codes need no server.
5. **Family Sharing** on the yearly and lifetime plans, so a partner or daughter who pays can cover her. That drives goodwill and reviews.
6. **Review prompt** (`requestReview`) only after a positive moment: a PDF is exported, or an experiment finishes with fewer surges. Never after a surge.

---

## 8. Monetization (final)

| Product | ID | US price | Notes |
|---|---|---|---|
| Monthly | `menomap.pro.monthly` | $9.99 | No trial |
| Yearly | `menomap.pro.yearly` | $49.99 | **7-day free trial**; default selection; "Best value"; Family Sharing on |
| Lifetime | `menomap.pro.lifetime` | **$99.99** | Family Sharing on |
| Visit Report | `menomap.visitreport.single` | **$4.99** | Consumable. One PDF covering up to 90 days. Offered as the second option when the paywall is closed from the PDF path. |

- Prices are set per territory; the purchasing-power tiers are in `Docs/MARKETS.md`. No weekly plan. No ads, anywhere, ever.
- **RevenueCat** runs in observer mode (`purchasesAreCompletedBy: .myApp`, StoreKit 2, anonymous IDs) for Apple Ads attribution. **It never receives health data.** The privacy label becomes Data Not Linked to You: Purchases and User ID. Health data is not "collected" because it never leaves the device. The store pitch: *"Your health data never leaves your iPhone."*

**Free** (what stays useful forever):
- The Surge button on every surface; after-the-fact logging
- Check-in
- 7-day heat map and stats
- Morning card
- Health read and write
- 8 Learn articles and Ask
- Medication list
- "Tell my person"
- The Heat Report cover card
- JSON export and delete

**Pro:**
- Patterns
- Experiments
- 30/90/365-day charts and full stats
- The full Heat Report
- The clinician PDF (any window, any language)
- The appointment prep generator
- Share cards without the watermark
- Dose reminders (kept as a convenience, no longer the selling point)

**Paywall triggers:**
- Tapping Create PDF
- Tapping a pattern or experiment
- Appointment countdown at T-7 with at least 5 days logged
- The third check-in

Never in session 1. The close button is always visible. No countdowns and no data threats.

Headline: "See the month, not just the day." When reached from the appointment path: "Walk in with notes."

---

## 9. Clinical credibility

- **The 8 Learn articles** are written as in the spec. Sources are drawn only from authoritative public bodies, and **each URL is fetched and checked live at build time**:
  - The Menopause Society (US)
  - NHS and NICE NG23 (UK)
  - Australasian Menopause Society and Jean Hailes (AU)
  - SOGC (CA)
  - International Menopause Society (fallback)

  The in-app label is **"Sources checked [date]"**, never "clinician reviewed", unless Rob later pays a menopause-certified clinician to review. That review is optional; it's what would take the content from 9 to 10.
- **Per-locale sources:** each locale links the national body where one is verified, otherwise the International Menopause Society.
- **Menopause Rating Scale (MRS): dropped** (Rob, 2026-09-29: "don't worry about these"). A commercial license would be needed from ZEG Berlin, so no validated questionnaire is shipped and the no-score rule in SPEC §4 stands.
- **Emergency copy** shows the local number from a verified per-country table (911, 999, 112, 000, 119…) and falls back to "your local emergency number."

---

## 10. Onboarding (revised, all skippable except legal)

1. **Promise**
2. **Why you're here**
3. **Apple Health.** "Bring in what you've already logged." Read and write permission, plus the 90-day import. On iOS 27, the stage comes from `menopausalState`.
4. **What to show on Today** (defaults: hot flashes, night sweats, sleep)
5. **Stage** (skipped if Health supplied it; the post-menopause bleeding note is unchanged)
6. **Next appointment?** (optional date and clinician name)
7. **Privacy and disclaimer** (the legal text from SPEC §1)
8. **"Put Surge one tap away."** Add the Control, set up the Action Button, install the Watch app, add the widget. Each step can be skipped, and each shows a 3-second looping demo.
9. **First action:** start a surge, or do the first check-in. If Health import found data, show "Here's your last 90 days" first. That's the "aha" moment.

---

## 11. Data model additions (to SPEC §4)

- `SurgeEvent.source`: app, liveActivity, control, watch, intent, afterTheFact, or healthImport. New fields: `SurgeEvent.hkSampleUUID?`, `wasNight`.
- `HKLink` (eventID ↔ sampleUUID, type, lastSyncedAt)
- `Appointment` gains `clinicianName?`, `readiness` (computed, not stored), and `pdfLanguage`.
- `Experiment` (kind, customTitle?, startDate, endDate, status, baselineWindowDays)
- `ShareSettings` (voice, showMedNames, showQR)
- `UserProfile` gains `voice`, `stageSource` (user or Health), `region` (for paper size and emergency number)

---

## 12. Insight rules (expanded from SPEC §13; same tone and minSamples rules)

1. `sleep_after_3plus_surges`, `alcohol_then_sweats`, `severity_change`, `missed_doses_note` (from the spec)
2. `peak_hour` (surge clock; needs 10 or more surges)
3. `trigger_share` (tag ranking; needs 10 or more tagged surges)
4. `wrist_temp_nights` (Health wrist temperature vs night-sweat nights, 14 nights paired; wording: "nights you logged… averaged…")
5. `weekday_pattern`
6. `treatment_timeline` (30 days before vs after a medication start; coincidence-check wording)
7. `experiment_result`

Every rule gets a unit test covering both insufficient data and fixture data.

---

## 13. Milestones (replaces SPEC §22)

Each milestone ends with a green `xcodebuild` for iOS **and** watchOS simulators, passing tests, and a note in `Docs/IMPLEMENTATION_PLAN.md`. **Rob sees simulator screenshots at the end of B, D and H** (per his design bar).

| # | Milestone | Contents |
|---|---|---|
| A | Skeleton + identity | `git init`, XcodeGen with 4 targets and the package; visual identity doc and `MenoTheme`; String Catalogs; SwiftData at an explicit URL; `AppContainer`; four tabs; disclaimer; delete-all |
| B | Capture | Onboarding (§10); Surge in-app + Live Activity + Control + Action Button + Siri + after-the-fact; check-in; medications; cycle and bleeding banner; 7-day heat map |
| C | Apple Health | Read/write, 90-day import, dedupe, observer, stage from Health, morning card, wrist temperature and sleep |
| D | Understand | Insight engine (§12) with tests; Week charts; the Stats infographics; experiments; Heat Report |
| E | Visit | Appointment countdown and readiness; prep questions; PDF (charts, language picker, A4/Letter, QR footer, watermarked free preview) |
| F | Commerce + Learn | StoreKit 2 + RevenueCat observer; paywall and triggers; trial; Visit Report consumable; Family Sharing; offer-code redemption; 8 articles with live-checked sources; local Ask; notifications |
| G | Watch + widgets | Watch app (breathing, Double Tap, Crown rating, complications, Smart Stack, `WatchConnectivity` queue); widget set (Surge button, 7-day heat, countdown, Lock Screen circular); StandBy night style |
| H | Share + growth | Share cards (4 kinds, 2 sizes), voice setting, "Tell my person", review-prompt rules, "Share MenoMap" friend pass |
| I | Localization | About 32 languages plus English regional variants through the WishLock pipeline, plus the **safety-copy audit** (§14); emergency table; per-locale sources; ASO per storefront (Appfigures and Apple Ads data) |
| J | Store | Screenshots per language (compositor); ASC app record, subscriptions, per-territory prices, privacy label, age rating; fastlane; TestFlight; **Rob approves screenshots** → submit |

---

## 14. Localization safety rule (new)

Medical and safety strings are tagged `SAFETY` in the source JSON: the disclaimer, bleeding banner, emergency copy, medication copy, Surge copy, "not proof" wording and PDF footer (about 40 strings). They get **three passes**:
1. Translator
2. Independent reviewer
3. **Back-translation auditor.** A separate agent translates back to English without seeing the source, and a diff checks the meaning. Any drift blocks the language.

Wry copy is *transcreated* (adapted, not translated literally), with a per-locale note, and the reviewer must confirm it isn't crude or offensive in that culture.

---

## 15. Rob's action items (none block Milestones A–H)

1. **The Apple Developer membership expires 2026-10-02**, three days from now per WishLock notes. Renew it, or TestFlight and the WishLock review are at risk.
2. ~~MRS license~~: dropped by Rob.
3. ~~China ICP~~: dropped by Rob, so China mainland is **off** at launch.
4. **gwlabs.app/menomap pages** (landing page, privacy, terms, clinicians) through Manus before submission.
5. **EU DSA trader status.** It must be "trader" to sell subscriptions in the EU. This is the open question from WishLock.
6. **About a 20-minute session** in Chrome for ASC and RevenueCat at the start of Milestone J (Claude asks at that point).
7. **Optional:** a menopause-certified clinician review of the 8 articles and the safety copy.
8. **Apple Ads budget:** proposed at Milestone J (Visited used about $600 in its first month).
