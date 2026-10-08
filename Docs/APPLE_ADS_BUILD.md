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

## Status (built 2026-10-08, all 20 PAUSED, start date Jan 1, 2027)

| Campaign | Countries | Daily budget | Ad groups (default max bid) | Search Match |
|---|---|---|---|---|
| MM - US - Category | US | $20 (plan says $14; lower before launch) | Tracker $1.80, HotFlash $2.00, NightSweats $1.80, Peri $2.00, Doctor-HRT $1.60 | off |
| MM - US - Brand | US | $2 | Brand $0.60 | off |
| MM - US - Competitor | US | $4 | Competitor $1.20 | off |
| MM - US - Discovery | US | $4 | Discovery $1.00 (broad), 49 exact negatives | on |
| MM - CA - Category | CA | $3 | Category $1.20 (all 35 US category terms) | off |
| MM - CA - Brand | CA | $1 | Brand $0.40 | off |
| MM - CA - Competitor | CA | $1 | Competitor $0.70 | off |
| MM - CA - Discovery | CA | $1 | Discovery $0.70 (broad), 49 exact negatives | on |
| MM - UK/IE/AU/NZ - Category | GB, IE, AU, NZ | $4 | Category $1.40 ("hot flush" + "hot flash" terms) | off |
| MM - UK/IE/AU/NZ - Brand | GB, IE, AU, NZ | $1 | Brand $0.50 | off |
| MM - UK/IE/AU/NZ - Competitor | GB, IE, AU, NZ | $1 | Competitor $0.90 (+ Newson / Health & Her terms) | off |
| MM - UK/IE/AU/NZ - Discovery | GB, IE, AU, NZ | $1 | Discovery $0.80 (broad), 48 exact negatives | on |
| MM - DE/AT/CH - Category | DE, AT, CH | $4 | Category $1.00 (German terms) | off |
| MM - DE/AT/CH - Discovery | DE, AT, CH | $1 | Discovery $0.60 (broad) | on |
| MM - FR - Category | FR | $3 | Category $0.85 (French terms) | off |
| MM - FR - Discovery | FR | $1 | Discovery $0.60 (broad) | on |
| MM - NL - Category | NL | $2 | Category $0.90 (Dutch terms) | off |
| MM - NL - Discovery | NL | $1 | Discovery $0.60 (broad) | on |
| MM - JP - Category | JP | $3 | Category $1.00 (Japanese terms) | off |
| MM - JP - Discovery | JP | $1 | Discovery $0.60 (broad) | on |

Total if every campaign ran: **$59/day**. The phased plan only turns on the English-speaking markets first
(US + CA + UK/IE/AU/NZ = $45/day as built, ~$35/day after lowering US Category to $14), and the DE/FR/NL/JP
campaigns from week 3 or later.

All campaigns: Search Results, Manage Bids (manual CPT), Reach All Eligible Users (no age/gender), Default product page.

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
