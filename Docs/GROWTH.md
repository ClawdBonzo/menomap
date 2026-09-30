# MenoMap — Growth Plan (items 1–12, approved by Rob 2026-09-29)

## What's built in the app

| # | Feature | Where | Notes |
|---|---|---|---|
| 1 | **Night Watch** | `Shared/NightWatch.swift`, `NightWatchController`, `NightWatchLiveActivity` | A Lock Screen Live Activity from bedtime to wake (8-hour cap) with a big Night sweat button, which becomes a timer and End button during a surge. It turns on after the evening check-in, when the app is opened near bedtime, from the bedtime notification, the Control, Siri, or a Shortcuts Sleep Focus automation. Setting: You → Night Watch. |
| 2 | **iMessage app** | `MenoMapMessages/` | 12 wry stickers rendered on device (so they translate) and 5 heads-up cards sent as branded bubbles that link to gwlabs.app/menomap. No health data is used. |
| 3 | **Story video** | `StoryVideo.swift` | 1080×1920, 6 s H.264: count-up, heat cells filling, surge clock, footer. Available from the Heat Report and the week share sheet. Free, because it's a viral surface. |
| 4 | **Clinic codes** | Paywall ("Have a code from your clinic or a friend?"), You → Redeem, You → "Tell my clinician about MenoMap" | The codes themselves are created in App Store Connect (see below). Handout: `Docs/ClinicKit/handout.html`. |
| 5 | **Reviews** | `AppointmentFollowUpCard`, experiment-improved, calm-stretch record, PDF closed; You → Rate / Send feedback | Asked only after positive moments, at most every 120 days. "Rate MenoMap" appears once `AppStoreID` is set in project.yml. Feedback goes to support@gwlabs.app. |
| 7 | **Cycle-phase pattern** | `InsightEngine.cyclePhase` | Uses period starts from Apple Health (menstrual flow with the cycle-start flag) and the cycle log; post-menopause and spotting are excluded. |
| 8 | **Tonight's heads-up** | `TonightHeadsUpCard` (Pro) | From 5pm on alcohol evenings, when the user's own history shows night sweats followed at least 60% of the time. Offers to turn on Night Watch. |
| 9 | **Weekly Wrap** | `WeeklyWrapCard` | Sunday afternoon and Monday, free, shareable (card or video). Optional Sunday 6pm reminder in You → Reminders. |
| 10 | **Sample preview** | `SamplePreviewView`, `SampleSeries` | Clearly labeled example data, never stored. Opened from the empty Pattern slot and from Week when there are fewer than 7 logged days. |
| 11 | **HRT schedules** | Medication editor | Every day, certain days (with a "Patch, twice a week" preset) or as needed. Reminders fire only on scheduled days, and Taken/Skipped only shows on due days. |

## 4 · Clinic program (App Store Connect setup, Milestone J)

- **Codes:** custom subscription offer codes on `menomap.pro.yearly`, "1 month free", new subscribers only.
  - One code per clinic: `CLINICNAME30` (e.g. `PATEL30`). Redemptions per code show which clinics send users.
  - A friend code: `MENOFRIEND`.
- **Limits:** custom codes allow a set number of redemptions per code; start at 500 per clinic and raise as needed.
- **Handout:** `Docs/ClinicKit/handout.html`. Print on A4 or Letter, and write the clinic's code in the box.
- **Web:** gwlabs.app/menomap/clinicians should host the same content plus the PDF sample (Manus).
- **Outreach:** menopause-certified clinicians and women's-health clinics. Start with 10 practices; offer a sample PDF built from demo data.

## 6 · Launch: World Menopause Day, Oct 18, 2026 (October is Menopause Awareness Month)

1. **Critical path:** developer membership renewal (expires Oct 2) → TestFlight → submit by about Oct 8 to leave review time.
2. **App Store featuring nomination** (App Store Connect → Featuring Nominations → New Launch), submitted about 2 weeks ahead. Draft:
   > **MenoMap: one tap for hot flashes, notes your clinician can read.** Built on Apple Health's new menopause support in iOS 27: MenoMap reads your stage and symptoms, writes every hot flash and night sweat back to Health, and puts a one-tap button on the Lock Screen, Action Button, Control Center and Apple Watch. Night Watch keeps a dim night-sweat button on the Lock Screen until morning. Patterns and a clinician PDF (in any supported language) turn a messy month into a clear conversation. Everything stays on device: no account, no cloud, no ads. Designed for readers 45–60 with large type, full Dynamic Type and VoiceOver.
3. **In-App Event** (App Store Connect → In-App Events) for "World Menopause Day: two-week Night Watch challenge", Oct 11–25.
4. **Social:** Weekly Wrap and story videos from the demo data; the sticker pack as a launch post ("stickers for the 3am club").
5. **Apple Ads:** Tier 1 keywords per Docs/MARKETS.md, starting Oct 11.

## 12 · Win-back and retention (App Store Connect setup only)

- **Win-back offer** (iOS 18+, shown automatically by the App Store and in StoreKit messages): yearly plan, 50% off the first year, for users whose subscription lapsed at least 30 days ago.
- **Promotional offer:** 1 month free on yearly for users who cancel within the trial (targeted through RevenueCat once connected).
- **Billing grace period:** on (16 days).
- The app already shows StoreKit messages (the default) and refreshes entitlements on `Transaction.updates`, so no code is needed.

## 13 · Launch status and post-approval runbook (updated 2026-09-30)

**Done**
- 1.0 (build 1) + Monthly, Yearly, Lifetime, Visit Report submitted for App Review 2026-09-30 (release: automatic on approval).
- Featuring nomination SUBMITTED (App Store Connect API, type APP_LAUNCH, publish date Oct 6, iPhone + Apple Watch, linked event).
- In-App Event "Two Weeks of Night Watch" (id 6817924472): DRAFT, badge Challenge, en-US text + card/details art
  (AppStore/event/), publish Oct 4, runs Oct 11-25 in the app's 173 territories. No deep link (menomap://nightwatch arms
  Night Watch immediately, too abrupt from a store tap).
- gwlabs.app/menomap pages live (Manus); link-preview follow-up in Docs/Web/MANUS_MENOMAP_FIX.md.

**On approval (same day)**
1. Submit the In-App Event for review (App Store Connect → In-App Events → Submit, or a review submission with the event).
2. `python3 Tools/asc_setup.py codes` (MENOFRIEND), `python3 Tools/asc_setup.py winback`, then one
   `python3 Tools/asc_setup.py clinic NAME30` per clinic.
3. Ask Manus to rerun step 6 of MANUS_MENOMAP_PROMPT.md (remove "Coming soon", add downloadUrl/offers).
4. Apple Ads: Tier 1 keywords only (Docs/MARKETS.md), capped until RevenueCat attribution is live.

**1.0.1 (next build)**
- RevenueCat: Rob creates the MenoMap app in RevenueCat (StoreKit 2 observer mode), uploads the App Store In-App Purchase
  key there himself, and pastes the public Apple SDK key into `RevenueCatAPIKey` in project.yml.
- Screenshot order: clinician notes move to frame 3 (Tools/asc_listing.py ORDER); upload with `fastlane metadata`.
- Localize the In-App Event text for the main storefronts (de, fr, es, ja, nl, it, pt-BR, sv, zh).
