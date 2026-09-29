# MenoMap — Implementation Plan & Status

Milestones from `Docs/SPEC_ADDITIONS.md` §13. Each milestone ends with a green iOS + watchOS build and passing tests.

**How to build and test**
- `xcodegen generate`
- `Tools/sim_run.sh -MMDemo -MMInMemory -MMPro` builds, installs and launches the demo.
- `cd MenoCore && swift test` runs 35 tests on the Mac in under a second.
- `xcodebuild … test` runs the 20 app tests in the simulator.

**Launch arguments (DEBUG):**
- `-MMDemo` loads 60 days of fictional data.
- `-MMSkipOnboarding`
- `-MMInMemory`
- `-MMPro` / `-MMFree` force the entitlement.
- `-MMTab week|visit|you` opens a tab.

| # | Milestone | Status (2026-09-29) |
|---|---|---|
| A | Skeleton + identity | ✅ git repo; XcodeGen with 5 targets (app, widgets, Watch app, Watch complications, tests) plus the MenoCore package; visual identity doc; `MenoTheme`; SwiftData; `AppContainer`; four tabs; disclaimer; delete-all |
| B | Capture | ✅ 9-step onboarding; Surge session (timer, 4-4-4 breathing, night mode, rating, tags); Live Activity; Control Center / Lock Screen control; Action Button and Siri intents; after-the-fact logging; rate-later; check-in (0–10 score bars, VoiceOver adjustable); medications with dose log; cycle and bleeding banner; 7-day heat strip. Verified in the simulator. |
| C | Apple Health | ✅ Read/write authorization (verified in the simulator); 90-day import with dedupe; observer and background delivery; stage from `menopausalState` (iOS 27); sleep and wrist-temperature cache; morning card. ⚠️ The import itself is untested with real Health data; the simulator had none. |
| D | Understand | ✅ 10 insight rules with 31 unit tests; Week stats (thermostat gauge, heat calendar 7/30/90/365, surge clock, trigger podium, records, check-in chart); patterns with the free weekly reveal; experiments; Heat Report; timeline |
| E | Visit | ✅ Appointment countdown and readiness ring; notifications at T-7, T-1 and T-0; topics and questions; vector PDF (2 pages, A4/Letter, language picker, QR footer); watermarked free preview. Verified in the simulator. |
| F | Commerce + Learn | ✅ StoreKit 2 manager, paywall, restore, Visit Report consumable, offer-code redemption, RevenueCat observer hook; 8 articles with live-checked sources; local Ask (20 FAQs); notifications; JSON export. ⚠️ Purchases can't be tested headlessly (the WishLock `SKTestSession` issue); test them from Xcode with `MenoMap.storekit`. |
| G | Watch + widgets | ✅ Watch app (start, haptic breathing, Double Tap, Crown rating, `WatchConnectivity`), verified in a watchOS simulator; Watch complications; iOS widgets (Surge button, 7-day heat, countdown, Lock Screen circular/rectangular/inline). ⚠️ Widget placement isn't verified headlessly. |
| H | Share + growth | ✅ Share cards (week, month, experiment, calm stretch; story or square; QR toggle; free-tier watermark); "Tell my person"; friend-pass share (code `MENOFRIEND` must be created in App Store Connect); review prompt rules |
| G+ | Growth items 1–12 (Docs/GROWTH.md) | ✅ Night Watch (verified on the simulator Lock Screen: arm → Night sweat → timer → End → "1 tonight"), iMessage stickers + heads-up cards, story video (verified 1080×1920, 6 s), clinic codes, review moments, cycle pattern, Tonight's heads-up, Weekly Wrap, sample preview, HRT schedules, notification tap routing |
| I | Localization | ⏳ Next. About 32 languages plus English regional variants through the WishLock pipeline, with a third safety-string back-translation audit (`Docs/MARKETS.md`). |
| J | Store | ⏳ Needs Rob: renew the developer membership; about a 20-minute App Store Connect / RevenueCat session; gwlabs.app/menomap pages; DSA trader status. |

## Tests
- **MenoCore (35):**
  - DST and window math
  - Every insight rule, with both insufficient data and fixture data
  - Stats and heat scale
  - Readiness
  - Severity mapping
  - Watch message round trip
  - Paper size and emergency number
  - Cycle-phase pattern
  - Tonight's heads-up
  - Sample series
- **App (20):**
  - Entitlement: lifetime, active, expired, revoked, and Visit Report alone
  - Ask fallback and matching
  - The post-menopause bleeding flag
  - Non-diagnostic bleeding copy
  - The PDF contains the disclaimer and footer (text extracted from the PDF)
  - The free preview is watermarked
  - Check-in merge keeps metrics that were turned off
  - Delete-all
  - Story video export (6 s, 1080×1920)
  - Patch schedule due days
  - Cycle starts skip post-menopause and spotting
  - Sticker and heads-up copy counts
