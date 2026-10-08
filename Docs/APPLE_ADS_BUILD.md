# MenoMap Apple Ads build (all paused / future-dated)

Based on `Docs/ADS_RESEARCH.md` §3. Apple Ads account: Advanced, org "Rob Goldstein" (20947890), app "MenoMap:
Menopause Tracker" (GW Capital Partners LLC). Naming: `MM - <geo> - <type>`.

**Rules for every campaign:**
- Placement: Search Results.
- Start date: Jan 1, 2027. Pause the campaign as soon as it's created; set the real date when you launch.
- Audience: Reach All Eligible Users, with no age or gender settings. Since 2026-09-01, Apple's attribution returns
  "false" for ad groups with age or gender set, so those installs would disappear from RevenueCat.
- Search Match: off, except in Discovery.
- Keywords: exact match (brackets), except in Discovery.
- Ad: Default product page for now. Swap in the matching custom product page (table at the bottom) once Apple approves
  it.

## Status

| Campaign | Status | Daily budget | Ad groups (default bid) |
|---|---|---|---|
| MM - US - Category | **Created** 2026-10-08, start Jan 1, 2027, **not yet paused** | $20 → lower to $14 | Tracker ($1.80) |
| MM - US - Category | to add: ad groups | | HotFlash ($2.00), NightSweats ($1.80), Peri ($2.00), Doctor/HRT ($1.60) |
| MM - US - Brand | to build | $2 | Brand ($0.60) |
| MM - US - Competitor | to build | $4 | Competitor ($1.20) |
| MM - US - Discovery | to build | $4 | Discovery ($1.00), broad + Search Match, all exact terms as exact negatives |
| MM - CA - Category | to build | $3 | Category ($1.20) |
| MM - CA - Discovery | to build | $1 | Discovery ($0.70) |
| MM - UK/IE/AU/NZ - Brand | to build | $1 | Brand ($0.50) |
| MM - UK/IE/AU/NZ - Category | to build | $4 | Category ($1.40), "hot flush" wording |
| MM - UK/IE/AU/NZ - Competitor | to build | $1 | Competitor ($0.90) |
| MM - UK/IE/AU/NZ - Discovery | to build | $1 | Discovery ($0.80) |

Total when everything runs: about $35/day (weeks 1–2 of the plan).

## Keywords (exact)

- **Tracker (done):** menopause app, menopause tracker, menopause symptom tracker, menopause log, menopause diary,
  menopause journal, symptom tracker menopause, menapause app, menopause apps
- **HotFlash:** hot flash, hot flashes, hot flash tracker, hot flash app, hot flash log, hot flashes menopause, hot flash relief
- **NightSweats:** night sweats, night sweats menopause, night sweat tracker, sleep menopause
- **Peri:** perimenopause, perimenopause app, perimenopause tracker, peri menopause, perimenopause symptoms,
  perimenopause symptom tracker, premenopause
- **Doctor/HRT:** hrt tracker, hrt app, hormone tracker, hormone therapy tracker, estrogen patch reminder, menopause doctor,
  menopause symptoms list, menopause questionnaire
- **Brand:** menomap, meno map, menomap app
- **Competitor:** balance menopause, balance menopause app, caria, caria menopause, evia, evia hot flashes, health and her,
  health & her menopause, perry perimenopause, flo perimenopause, clue perimenopause. Never bid on bare "flo" or "clue".
- **UK/IE/AU/NZ extras:** hot flush, hot flushes, hot flush tracker, hot flush app, hrt app, hrt tracker, menopause app uk,
  newson menopause, health and her app
- **Discovery seeds (broad):** menopause, perimenopause, hot flash, night sweats, hrt

## Custom product pages (submitted to Apple 2026-10-08)

| Page | Use with |
|---|---|
| Doctor visit notes | Category › Tracker, Doctor/HRT |
| Night sweats | Category › NightSweats, HotFlash |

## Before launch

1. In RevenueCat, connect Apple Ads (Integrations → Apple Search Ads, Sign in with Apple) so campaign and keyword names
   show up next to trials and revenue.
2. Check each keyword's popularity in the Apple Ads keyword tool and drop any with popularity of 5 or less unless clearly
   on-intent.
3. Change the start dates to the launch day and unpause.
