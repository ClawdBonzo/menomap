# MenoMap — Decisions

Decisions made during the build. Product decisions from Rob are in `Docs/SPEC_ADDITIONS.md`; these are the implementation calls.

| # | Decision | Why |
|---|---|---|
| 1 | **iOS 18.0 minimum**, iOS 27 Health types behind `#available` | Reach: this audience upgrades phones slowly. The stage and bleeding-after-menopause Health types only exist on iOS 27. |
| 2 | **SwiftData store at an explicit URL** in Application Support, with `cloudKitDatabase: .none` | The App Group entitlement would otherwise move the store into the shared container (WishLock lesson). Guideline 5.1.3(ii) bans health data in iCloud. Normal encrypted device backups still include it. |
| 3 | **Gregorian day keys** (`DayKey`) for every window; DST covered by tests | Calendar-day windows, not rolling hours; Buddhist, Japanese and Islamic device calendars can't break windows. |
| 4 | **A "night"** runs from noon to noon, keyed by the morning: surges before 12:00 count toward that morning's night | Pairs night sweats with that morning's sleep score. "Night surge" for stats means 21:00–06:59, or the night-sweat kind. |
| 5 | **The evening check-in asks "Alcohol today?"**, not the spec's "Alcohol last evening?" | It's asked in the evening, so "today" is what the user means. It pairs with the following night. |
| 6 | **Health writes are limited to surges and bleeding.** Check-in scores are not written. | Guideline 5.1.3(ii): don't write inaccurate data. A 0–10 mood score isn't Apple's "mood changes" symptom. |
| 7 | **Health samples carry `HKMetadataKeySyncIdentifier` + `SyncVersion`**; imports skip MenoMap's own samples by metadata and bundle ID | Edits replace the sample in place, and importing never duplicates. |
| 8 | **The phone is the only writer to Health.** The Watch sends finished surges via `transferUserInfo`. | One writer means no duplicate samples, and delivery is queued even when the phone is away. |
| 9 | **Surge intents are `LiveActivityIntent`s** compiled into both the app and widget targets | They run in the app process, so a Control, the Action Button, Siri or a widget can start the timer and Live Activity without opening the app. |
| 10 | **Ending from the Lock Screen saves the surge unrated.** Today shows a "Rate your 3:12am night sweat" card for 3 days. | Rating on the Lock Screen isn't possible; we never invent an intensity. |
| 11 | **A timer running over 60 minutes is saved with unknown duration (0)** | Almost certainly forgotten; inventing a length would corrupt stats. |
| 12 | **Heat level = sum of intensities per day** (unrated counts as 3), bucketed 0/1–3/4–6/7–10/11–15/16+ | Combines count and strength; the number is always printed on the cell. |
| 13 | **Insight rules return structured numbers** (MenoCore); the app writes the copy | Numbers are testable on the Mac with `swift test`; copy is localizable. |
| 14 | **The Today pattern slot excludes experiment results** | Those have their own card and share flow. |
| 15 | **Free users get one pattern reveal per week** (WishLock pattern); the others are blurred with the title visible | Shows the value without giving it away. |
| 16 | **The PDF is SwiftUI pages rendered as vector PDF** via `ImageRenderer` into a `CGContext` | Real text (searchable, testable), sharp print, same components as the app. |
| 17 | **The PDF language picker swaps `Bundle.main`'s lookup** to the chosen `.lproj` during synchronous rendering | Every existing `String(localized:)` call follows the picked language without passing bundles everywhere. |
| 18 | **Visit Report credits are stored locally** (consumable) and not restorable | That's Apple's model for consumables; Pro users never spend credits. |
| 19 | **RevenueCat key is read from Info.plist `RevenueCatAPIKey`** and is empty until the project exists | The app runs on StoreKit 2 alone; RevenueCat only records purchases (observer mode). |
| 20 | **The TimelineEvent and Insight models from the spec are not persisted** | Both are derived (timeline from surges, check-ins and med starts; insights computed live). Spec §4: "Do not add models for later." |
| 21 | **Default voice is Wry or Straight by locale** (`Locale.defaultVoice`) | SPEC_ADDITIONS §6. The user can change it in You. |
| 22 | **Learn sources were fetched and checked on 2026-09-29** (NHS pages, The Menopause Society). NICE NG23 returns 403 to automated fetching, so it isn't linked. | Spec rule 11: no link that wasn't verified. |
| 23 | **Menopause Rating Scale dropped** | Rob, 2026-09-29. A commercial license would be required. |
| 24 | **China mainland off at launch** | Rob, 2026-09-29. No ICP filing. |
| 25 | **Emergency numbers table** (`RegionInfo.emergencyNumbers`) needs a per-country check before release | It's safety copy; the fallback is "your local emergency number". |
| 26 | **Review prompt** fires only after closing a full PDF, at most every 120 days | A positive moment, never after a surge. |
| 27 | **Night Watch is one Live Activity for the whole night**; a surge started while it's on updates it instead of starting a second one | One Lock Screen element, and night mode stays dim. |
| 28 | **Night Watch arms from the check-in, near-bedtime app opens, a notification tap, the Control, Siri or a Shortcuts Sleep Focus automation** | iOS can't start a Live Activity on a schedule without a push server, and we have no server. |
| 29 | **Stickers are rendered on device** from localized strings (not a static sticker pack) | They translate along with the app. |
| 30 | **The story video renders frames with ImageRenderer into AVAssetWriter** (6 s, 30 fps) | Same palette and components as the share cards; no third-party code. |
| 31 | **The sample preview uses `SampleSeries`** (in MenoCore, shipped in Release) and is clearly labeled; it's never stored | Shows new users the payoff on day one without polluting their data. |
| 32 | **Review prompts** fire after: a good appointment follow-up, an improved experiment (once each), a new calm-stretch record of 3+ days, or closing a full PDF. Max once per 120 days. | Only positive moments; nothing gates or filters reviews. |
| 33 | **A surge is saved before its state is cleared** | Night Watch's "tonight" count must include the surge just ended (found in simulator testing). |
