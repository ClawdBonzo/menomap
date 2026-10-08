# MenoMap: Paid Acquisition Research and Plan

Researched 2026-10-08 for Rob. Companion to `Docs/MARKETS.md` (tiers, price bands, glossary) and `Docs/GROWTH.md` (launch runbook).

**How to read this.** Figures marked **[S]** are sourced, with the source and data period in brackets. Figures marked **[E]** are my estimates, with the reasoning given. Most public benchmarks come from vendors (AppTweak, SplitMetrics, MobileAction, Adapty, RevenueCat). Their samples skew toward larger advertisers and toward each vendor's own customers, so treat them as order-of-magnitude anchors. **No public benchmark is specific to menopause apps.** The first 2–4 weeks of MenoMap's own Apple Ads data will outrank everything in this document.

---

## 0. The answer on one page

**Ranked channels for MenoMap at $20–100/day:**

| Rank | Channel | Verdict | Why |
|---|---|---|---|
| 1 | **Apple Ads, Search Results, exact-match menopause keywords** | **Start now, ~70–100% of paid budget** | Highest intent. It's also the **only channel measured end to end in your current stack**: RevenueCat AdServices gives keyword → install → trial → paid with no IDFA, no ATT and no MMP. Health & Fitness CPT is about the median. |
| 2 | **Menopause creators (micro, IG/TikTok/YouTube) with offer codes and App Store campaign links** | Test in weeks 3–6 ($500–1,000 total) | Best audience fit for women 45–60, and a trusted voice suits a health product. Measured by offer-code redemptions plus App Store Connect campaign links, with no SDK. |
| 3 | **Newsletters and podcasts in the menopause niche** | One or two small tests in weeks 3–8 | Strong fit. Many small menopause newsletters accept sponsors. Measured the same way as creators (codes and links). |
| 4 | **Apple Ads Product Pages placement** ("You might also like") | Small test in weeks 7–12 | Cheap taps, but weak conversion (~18% CR) and you can't pick which apps' pages you appear on. |
| 5 | **Meta (FB/IG) Advantage+ app campaigns** | **Optional** weeks 7–12 test, only after a small SKAN code change | Big 45–64 female audience, but health interest targeting is gone, lower-funnel events are restricted for health advertisers, and without the Meta SDK or an MMP you only get SKAN postbacks. Learning needs about 50 events a week. |
| 6 | Reddit | Organic and community participation only for now | r/Menopause is large and on-topic, but conversion tracking for app installs needs SKAN/MMP, and health-condition targeting is restricted. |
| 7 | Pinterest | Skip for now | App-install campaigns require an MMP. Cheap CPMs, but measurement is weak. |
| 8 | TikTok Ads (paid) | Skip, except Spark Ads boosting a creator's post | Ages 45–54 are only ~8% of users, and iOS app campaigns need an MMP or the TikTok SDK. |
| 9 | Google App Campaigns (iOS) / YouTube | **Skip** | They need Firebase/GA4 or an MMP, which breaks the "no analytics SDK" promise. |
| 10 | Microsoft/Bing app install ads | Skip | They need an MMP, and the audience is small. |
| — | Apple Ads Today tab / Search tab | Skip at this budget | Low intent. Today tab CR is ~14%, and Search tab can't be keyword-targeted. |

**Starting budget split (paid only):**

| Phase | Daily | Apple Ads SR | Creators/newsletters | Other tests |
|---|---|---|---|---|
| Weeks 1–2 | $30–40 | 100% | 0 (line up deals) | 0 |
| Weeks 3–6 | $50–75 | ~75% | ~25% (as flat fees, ~$150–250/week) | 0 |
| Weeks 7–12 | $75–100 | ~65% | ~20% | ~15% (Product Pages, or the Meta SKAN test) |

**Apple Ads structure:** 4 campaign types (Brand / Category / Competitor / Discovery) × 3 geo groups to start (US; CA; UK+IE+AU+NZ, which use "hot flush"). All Search Results, **Advanced (not Basic)**, Customer type = New users. **No age or gender refinements**: since 2026-09-01, Apple's AdServices returns `attribution: false` for any ad group with age or gender set, which would blind RevenueCat. Each category ad group gets its own Custom Product Page. Full lists are in §3.

**The single biggest lever isn't a channel; it's the paywall.** 82% of trial starts happen on install day [S: RevenueCat SOSA 2025], and MenoMap's spec says the paywall is "never in session 1." That's defensible as a product and brand choice, but it will roughly halve install-to-trial for paid traffic and slow every kill/scale decision. Consider a dismissible, value-first paywall at the end of onboarding, A/B tested on paid traffic. Details are in §4.

---

## 1. Measurement reality for MenoMap (read before choosing channels)

What the app has today (checked in the repo):
- RevenueCat in observer mode (`purchasesAreCompletedBy: .myApp`, StoreKit 2) **with `enableAdServicesAttributionTokenCollection()` already called** (`MenoMap/Services/Subscription/SubscriptionManager.swift`).
- **No `SKAdNetworkItems` in `MenoMap/Info.plist`**, no ATT prompt, no analytics SDK.

What that means per channel:

| Channel | Install attribution | Trial/paid attribution | What it would take |
|---|---|---|---|
| Apple Ads | Yes (AdServices, no ATT needed) | **Yes, down to keyword**, in RevenueCat charts | Nothing in the app. Rob: in RevenueCat, connect Apple Ads (the "Advanced" integration, Sign in with Apple) so campaign and keyword *names* resolve. Data can take up to 7 days to arrive. [S: RevenueCat docs] |
| Creators, newsletters, podcasts, any web link | Partly: App Store Connect **campaign links** (`ct=` token) show impressions, page views, downloads, sales and subscriptions per token. Data appears once a token has ≥5 first-time downloads, and only from users who share analytics with developers. [S: App Store Connect Help] | Partly: **offer-code redemptions per code** (already planned: `MENOFRIEND`, clinic codes) | Make one `ct` token and one offer code per partner. Optionally make a CPP per partner (its own URL, also reported in App Analytics). |
| Meta | Only via SKAN postbacks | Only coarse/fine SKAN conversion values | Add Meta's SKAdNetwork IDs to Info.plist and call `SKAdNetwork.updatePostbackConversionValue` natively (no Meta SDK; SKAN is Apple's privacy-preserving framework, not tracking). Configure the CV schema in Meta Events Manager, with the "SKAdNetwork for the Facebook SDK" toggle off. [S: Linkrunner/AppsFlyer/Tenjin docs on SDK-less Meta SKAN] |
| TikTok, Pinterest, Microsoft, Reddit app-install campaigns | Need an MMP or the platform SDK for SKAN config | Same | Not compatible with the current privacy promise without an MMP. Use creator Spark Ads or link-traffic campaigns with `ct` links instead. |
| Google App Campaigns (incl. YouTube) | Need Firebase/GA4 or an App Attribution Partner, or a manual SKAN setup | Same | Conflicts with "no analytics SDK". **Skip.** |

Two policy facts that shape the plan:
1. **Apple Ads + age/gender targeting = no attribution** (from 2026-09-01). [S: AppsFlyer bulletin; RevenueCat docs; Apple AdServices API v4 PDF dated 2026-09-01] Age/gender refinements also exclude users with Personalized Ads off; one source estimates ~78% of search volume is lost. [S, single source: mbadv.agency] So let the keywords do the targeting.
2. **Meta health-advertiser restrictions** (since January 2025): health & wellness data sources can't optimize on, or build custom audiences from, lower-funnel standard events (Purchase, AddToCart and below). This covers Pixel, CAPI and the App Events API. App Install, ViewContent and Search are not restricted. [S: Freshpaint, Ours Privacy, PixelFlow, Jan 2025] Meta also removed health-cause detailed targeting in January 2022. [S: Meta via Search Engine Land/Adweek] So on Meta you'd optimize for **installs** (or SKAN CV-based events) and rely on creative and broad targeting to find women 40–60.

---

## 2. Channel-by-channel comparison

### 2.1 Apple Ads

| Placement | Cost benchmarks | Fit for women 40–60 | Min. viable budget | Measurability for MenoMap | Notes |
|---|---|---|---|---|---|
| **Search Results** | **US Health & Fitness: median CPT $1.68, CPI $3.77, CR 50.3%, TTR 7.5%** [S: AppTweak, ~2,800 US advertisers, Jan–Dec 2025, pub. Aug 2026]. Another source puts H&F CPT at $1.59 [S: SplitMetrics 2026 report via trysonar]. All-category: US CPT $1.91 / CPI $4.06; UK $1.35 / $2.60; CA $1.17 / $2.24; AU $1.15 / $2.19; DE $1.11 / $2.14; FR $0.92 / $1.78; JP $1.11 / $2.57 [S: AppTweak 2025 data]. Adapty puts the median CPI across 90 markets at $0.51 and the US at $2.51, with "Health Tracker" niche CR 66% and CPA $1.89 [S: Adapty, 8,000+ apps, 2025 data]. | Excellent: people searching "perimenopause", "hot flash", "menopause app" are the audience. Demographics are irrelevant to keyword intent. | No minimum spend. ~$10/day per geo group is enough to learn keyword CPT/TTR/CR. **Maximize Conversions** (target-CPA bidding, GA Feb 2026) wants a daily budget of 5–10× target CPA and ≥5 installs/day [S: NeoAds Substack, 2026], which is too much for week 1. Use manual CPT. | **Best**: keyword-level trials and revenue in RevenueCat. | Since March 2026 up to **two ads** appear per query (the second sits around position 3), with no separate bidding [S: ppc.land, Zoomd, Macworld]. Adapty reports Apple Ads users start trials at 3.66% of installs vs 1.45% for other channels, and pay at 1.92% vs 0.91% [S: Adapty 2026; vendor]. |
| Search tab | 2025: CPT $0.95, CR 54.6%, TTR 1.25%, CPA $1.81; Q4 CPT rose to $1.23 [S: MobileAction 2026 report] | Poor. You can't target by keyword, and demographic refinements now kill attribution. | $20+/day to get any volume | Install-level OK. Trial rate is likely low. | Cheap installs from the wrong people. Skip. |
| Today tab | 2024: CPT $0.83, **CR 13.6%**, TTR 0.38%, CPA $6.28 [S: MobileAction 2025 report, 2024 data]. Agencies suggest it only above ~$3k/month [S, low confidence: claudepluginhub summary]. | Broad and untargeted | High | Install-level | Skip. |
| Product Pages ("You might also like") | 2025: CPT $0.93–1.02, CR 18%, TTR 3.3%, CPA $5.26–5.67 [S: MobileAction 2026 report] | Medium. Apple decides which pages you show on (often category peers). On Caria's page the "You might also like" row lists Balance, Health & Her, Johns Hopkins Menopause Guide, Evia and Stella [S: App Store, fetched 2026-10-08]. | $5–10/day | Install-level, trials in RevenueCat | Phase-3 test only. CPA is ~1.5–2× Search Results. |

**Health/medical ad policy (Apple):** ad text is generated from your App Store metadata, so whatever passed App Review is what shows. Apple prohibits ads for health products or claims "not sufficiently substantiated" and bans targeting based on HealthKit data [S: ads.apple.com/policies; App Review Guidelines]. Keyword bidding on competitor brand names is allowed. Keep store copy non-diagnostic, as it already is.

### 2.2 Meta (Facebook / Instagram), including Advantage+ app campaigns

- **Costs:** "Wellness & Holistic Health" US CPI averaged $10.10 (monthly median $6.18), Oct 2024–Oct 2025 [S: Superads tool. It aggregates connected ad accounts, mixes iOS/Android and web campaigns, and is **vendor data of unknown sample**]. Fitness & wellness CPMs run $9–19, and health & wellness CPM rose ~38% in 2025 to ~$20.70 [S: TopGrowthMarketing, aggregator, low confidence]. Adapty's Meta playbook expects purchase-optimized CPI at "5–10×" install CPI [S: Adapty blog, Feb 2026].
- **Audience fit:** strong. In the US, women aged 45–54 are ~7.4% of Facebook's 291M users and 55–64 another ~6.5%; on Instagram they're 7.3% and 5.3% [S: NapoleonCat, Nov 2025].
- **Minimum viable budget:** creative discovery at $20–30/day in Tier 1; conversion validation at $150–200/day, aiming for 50+ events a week [S: Adapty, Feb 2026]. Optimizing on trials at $20–30/day won't exit learning, so you'd be optimizing on installs.
- **Measurability without an MMP:** SKAN only, after an Info.plist + native CV code change (§1). Expect gaps of up to 50% on some days and use blended ROAS [S: Adapty]. Without that change, Meta app-promotion campaigns can't receive iOS install postbacks for MenoMap.
- **Policy:** health detailed targeting removed (2022). Health & wellness data-source restrictions (2025) block lower-funnel optimization. The **personal attributes** rule means copy can't assert or imply the viewer has a condition ("Are you in perimenopause?" or "Your hot flashes…" get rejected); "Track hot flashes in one tap" is fine. Health products need 18+ targeting [S: Accelerated Digital Media 2026 guide; Meta via Search Engine Land].
- **Verdict:** a reasonable weeks 7–12 experiment **only if** you ship SKAN support and have 3–5 strong video creatives (creator UGC works best). Budget $25–35/day for 3 weeks, optimizing for installs, and judge on blended trials and revenue (RevenueCat "non-Apple-Ads" trials, plus App Store Connect source = "App Referrer: Instagram/Facebook").

### 2.3 TikTok

- **Costs:** an aggregator claims H&F CPI of $1.20–2.40 on TikTok [S, **low confidence**: RocketShip HQ summary, unclear sample, likely Android-heavy and younger].
- **Fit:** weak for paid targeting. ~8% of users are 45–54 [S: aggregator stats]. TikTok says 30%+ of its users are over 40, 61% of them women [S: Astellas/Pulse coverage, older figure]. Menopause creator content does well organically (Astellas ran TikTok menopause-awareness creator ads).
- **Minimum budget:** ~$20/day ad-group minimum (platform standard). Learning needs ~50 conversions a week.
- **Measurability:** iOS app campaigns need SKAN configured through an MMP or the TikTok SDK [S: TikTok Ads help]. Spark Ads (boosting a creator's post) pointing at an App Store `ct` link is measurable via App Store Connect.
- **Policy:** healthcare is a "Restricted" industry needing pre-authorization in some markets. 18+ only. No guaranteed-outcome claims and no before/after imagery [S: Accelerated Digital Media; TikTok policies].
- **Verdict:** use only as Spark Ads on creator posts that already perform organically.

### 2.4 Pinterest

- **Costs:** CPM $3–10 overall and ~$4–8 for health & fitness in 2026 [S: Hubfluence/Cropink/Trackbee, aggregators].
- **Fit:** good (female-skewed, "planning" mindset).
- **Measurability:** app-install campaigns need MMP integration (Adjust/AppsFlyer/Branch/Kochava/Singular/Tune) [S: Pinterest help]. Without one you can run traffic campaigns to a `ct` link only.
- **Policy:** you can't target based on sensitive health or medical conditions [S: Accelerated Digital Media].
- **Verdict:** skip paid. Maybe post Weekly Wrap and story-video pins organically.

### 2.5 Google App Campaigns (iOS) and YouTube

- **Costs:** H&F iOS CPI $2.00–5.50 [S, low confidence: semnexus 2026 blog].
- **Measurability:** needs Firebase/GA4 (recommended, v12.12.1+ for on-device measurement) or an App Attribution Partner. A manual SKAN setup exists but is poorly supported for optimization [S: Google Ads Help 10384955, 14892597].
- **Policy:** Google's "Health in personalized advertising" bans personalized targeting for physical or mental health conditions and for issues with intimate body functions. Menopause isn't named, but expect it to be treated as sensitive: contextual and keyword placement are fine, custom audiences are not [S: Google Ads policy 16701855].
- **Verdict:** skip. It would mean adding an analytics SDK, which contradicts the store pitch.

### 2.6 Reddit

- **Costs:** health & wellness CPC $0.30–1.00, CPM $3–8; app-install CPA ~$2.50 (all categories); $5/day minimum [S: Webtonic, Jul–Oct 2026, **agency blog, low confidence**].
- **Fit:** strong communities: r/Menopause ~211k and r/Perimenopause ~59k members [S: GummySearch snapshot, date unclear; **verify**].
- **Measurability:** Reddit supports SKAN 4.0 for app-install campaigns, but setup normally goes through an MMP [S: ppc.land].
- **Policy:** no targeting on sensitive health conditions. Subreddit/community targeting exists, but health communities need careful, non-diagnostic messaging [S: Webtonic; Reddit policy].
- **Verdict:** start with honest founder participation (follow each sub's self-promotion rules). A paid test comes later, as link traffic to a `ct` link.

### 2.7 Newsletters and podcasts (menopause niche)

- **Inventory found:** Hotflash inc (newsletter + podcast; #1 Women's Health on Goodpods per its own claim), My Menopause Medicine (Menopause Society-certified clinician), Unmasked Midlife, Morphus, Perimenopaws. All list "accepts sponsors" [S: Reletter, 2026]. The Vajenda (Dr Jen Gunter, OB/GYN) has 127k+ subscribers and accepts sponsors [S: Reletter]. Podcasts: Dr Streicher's *Inside Information* (1M+ downloads, self-reported), Hello Menopause, The Happy Menopause (UK) [S: podcast sites].
- **Costs:** podcast host-read mid-roll $25–50 CPM, programmatic $5–15 [S: Podder 2026]. For newsletters, ask for the media kit. A typical niche newsletter runs ~$20–60 CPM on subscribers [E: general market norm]. A 5–15k-subscriber menopause newsletter is likely $150–600 per placement [E].
- **Fit:** excellent. The audience is self-selected and often already engaged with clinicians, which matches the clinician-PDF hook.
- **Measurability:** a dedicated offer code (e.g. `HOTFLASH30` = 1 month free on yearly) plus a `ct` link and, ideally, a dedicated CPP.
- **Policy:** each publisher's own rules. Keep claims to tracking and visit prep.
- **Verdict:** 1–2 tests in weeks 3–8. Prefer clinician-led newsletters (on-message for "notes your clinician can read").

### 2.8 Creators (menopause IG/TikTok/YouTube)

- **Landscape:** top accounts include @drmaryclaire (Dr Mary Claire Haver), @tamsenfadal, @menopause_doctor (~830k, Dr Louise Newson, **who founded competitor Balance, so avoid**), @letstalkmenopause, @menopausewhilstblack, @ohhelloperry (**competitor Perry**), @hotflashinc, @megsmenopause, @blackgirlsguidetomenopause [S: iqfluence, HypeAuditor, Collabstr listings, 2026]. Collabstr lists 64 "menopause" and 861 "perimenopause" creators open to paid deals.
- **Costs:** micro creators (10k–100k) usually charge $100–500 per IG feed post. The average paid Instagram price on Collabstr is ~$193. Rates roughly double above 100k followers [S: Collabstr, Meltwater, IMH 2026]. Big clinician-creators (millions of followers) cost far more, and many sell their own products [E].
- **Fit:** excellent. Trust matters in this category, and creator video is also the best raw creative for any later Meta test.
- **Measurability:** offer code + `ct` link per creator. Ask for 30-day usage rights so you can reuse the video.
- **Policy:** FTC/ASA disclosure (#ad). No treatment claims. Creators must not imply the app diagnoses anything.
- **Verdict:** 3–5 micro creators at $150–300 each in weeks 3–6. Keep those whose code redemptions plus attributed installs come in under your cost-per-trial target, and Spark/partnership-boost the best post.

### 2.9 Microsoft/Bing

App install ads run only in US, CA, UK, AU, DE, FR, IN and BR, and track only through MMPs [S: Microsoft Advertising help]. **Skip.**

---

## 3. Apple Ads playbook

### 3.1 Competitors: verified (App Store, 2026-10-08) and how to treat them

| App | Exists? | Category / price | Bid on it? |
|---|---|---|---|
| **Balance – Menopause & Hormones** (id1503345959, Dr Louise Newson; Editors' Choice; 4.7★, 1.1k ratings) | Yes | H&F; Balance+ up to $98.99/yr | **Yes** ("balance menopause", "balance app menopause"). Not bare "balance", which is too ambiguous. |
| **Caria: Menopause & Midlife** (id1477621356; 4.6★, 1.4k) | Yes | H&F; $5.99/mo, $47.99/yr | Yes |
| **Evia: Hot Flashes & Menopause** (id1582336046; hypnotherapy, Mindset Health) | Yes | H&F | Yes ("evia", "evia hot flashes") |
| **Health & Her** (id1519199698) | Yes | H&F; free with own-brand supplements | Yes (UK-heavy) |
| **Stella | Menopause relief** (id1577904186) | Yes, **but now distributed mainly through insurers/employers** | — | Low priority |
| **perry: Perimenopause Community** (id1544428724; 4.9★, 244) | Yes, **Social Networking** category | $7.99/mo, $79/yr | Test "perry perimenopause" |
| **Midday** (Lisa Health × Mayo Clinic) | Announced 2022–23; **current App Store listing not confirmed** | — | Only if Apple Ads keyword research shows volume |
| **Flo** ("Flo for Perimenopause", July 2025) and **Clue** (Perimenopause mode in Clue Plus) | Yes (Flo is #4 and Clue #17 US H&F top grossing) | — | Don't bid on "flo"/"clue" (huge, younger, period-tracking intent). Test "flo perimenopause" and "clue perimenopause" only. |
| **New 2026 indie trackers**: MidLife: Menopause Tracker (privacy-first, PDF, one-time purchase, **closest positioning to MenoMap**), Aster, MenoWise, Flare — Hot Flash Tracker, Menopal, HotFlash – Menopause Log, Midrise, thePause, Johns Hopkins Menopause Guide | Yes | — | Watch them. They will also bid on "menopause tracker" and "hot flash tracker", so expect CPT to rise there. Small competitor ad group to start. |

None of the menopause-specific apps appear in the **US H&F top-100 grossing** (Flo #4, Clue #17, Natural Cycles #29, Stardust #73 are the women's-health entries) [S: AppBrain chart, 2026-10-08]. **The niche is real but small in revenue.** That is fine for an indie app, but it caps how much Apple Ads volume exists.

### 3.2 Campaign structure

Use separate campaigns per geo group (bids differ) and per intent. All are Search Results, Advanced, Customer type = **New users**. No age/gender refinements. Use exact match in Brand/Category/Competitor, and broad match + Search Match only in Discovery. Every exact keyword is also added as an **exact negative in Discovery**.

```
US  ─┬─ MM_US_Brand        (exact)  menomap, meno map, menomap app
     ├─ MM_US_Category     (exact)  ad groups: [Tracker] [HotFlash] [NightSweats] [Peri] [Doctor/HRT]
     ├─ MM_US_Competitor   (exact)  balance menopause, caria, evia ...
     └─ MM_US_Discovery    (broad + Search Match, low bids, negatives = all exacts)
CA  ─ same 4 (hot flash wording), lower bids
UK+IE+AU+NZ ─ same 4 with "hot flush" wording
Week 3+: DE+AT+CH (de), FR (+BE/CH-fr), NL(+BE-nl), Nordics, JP — Category + Discovery only at first
```

Week 1 Search Match can show irrelevant terms ("weight loss", "period tracker"). Check the Search Terms report every 2–3 days and add negatives.

### 3.3 Keyword lists

*Glossary terms come from `Docs/MARKETS.md` (translator-seeded) plus Apple Ads usage norms. Check each term's **popularity in Apple Ads' keyword recommendations** before launch, and drop any with popularity ≤5 unless clearly on-intent.*

**English, US/CA ("hot flash")**
- *Tracker:* menopause app, menopause tracker, menopause symptom tracker, menopause log, menopause diary, menopause journal, symptom tracker menopause, menapause app (misspelling), menopause apps
- *HotFlash:* hot flash, hot flashes, hot flash tracker, hot flash app, hot flash log, hot flashes menopause, hot flash relief (intent risk: they want relief, so watch trial rate)
- *NightSweats:* night sweats, night sweats menopause, night sweat tracker, sleep menopause
- *Peri:* perimenopause, perimenopause app, perimenopause tracker, peri menopause, perimenopause symptoms, perimenopause symptom tracker, premenopause
- *Doctor/HRT:* hrt tracker, hrt app, hormone tracker, hormone therapy tracker, estrogen patch reminder, menopause doctor, menopause symptoms list, menopause questionnaire (*MRS* / *Greene scale* if popularity allows)
- *Competitor:* balance menopause, balance menopause app, caria, caria menopause, evia, evia hot flashes, health and her, health & her menopause, perry perimenopause, flo perimenopause, clue perimenopause, midlife menopause tracker, menowise, aster menopause, midday menopause (if it has volume)

**English, UK/IE/AU/NZ:** same lists with **hot flush, hot flushes, hot flush tracker, hot flush app**, plus "hrt app", "hrt tracker", "menopause app uk" (high priority, since HRT is a mainstream term in the UK), "balance app newson", "newson menopause", "health and her app".

**German (DE/AT/CH):** wechseljahre, wechseljahre app, wechseljahre tracker, wechseljahresbeschwerden, hitzewallungen, hitzewallung, nachtschweiß, perimenopause, menopause, menopause app, hormonersatztherapie (watch intent)
**French (FR/BE/CH/CA-fr):** ménopause, menopause (no accent), appli ménopause, application ménopause, bouffées de chaleur, sueurs nocturnes, périménopause, préménopause, suivi ménopause
**Dutch (NL/BE):** overgang, overgang app, overgangsklachten, opvliegers, nachtzweten, menopauze, perimenopauze
**Spanish:** ES: menopausia, sofocos, sudores nocturnos, perimenopausia, app menopausia. MX/LatAm: **bochornos**, menopausia, climaterio
**Italian:** menopausa, vampate, vampate di calore, sudorazioni notturne, perimenopausa, app menopausa
**Portuguese (BR):** menopausa, climatério, fogachos, calorões, ondas de calor, suor noturno, perimenopausa
**Japanese:** 更年期, 更年期 アプリ, 更年期障害, ホットフラッシュ, 寝汗, 閉経, プレ更年期, 更年期 記録
**Korean:** 갱년기, 갱년기 앱, 안면홍조, 폐경, 갱년기 증상
**Nordics:** SE: klimakteriet, övergångsåldern, värmevallningar, nattsvettningar · DK: overgangsalder, hedeture · NO: overgangsalder, hetetokter · FI: vaihdevuodet, kuumat aallot

### 3.4 Starting bids and daily caps (manual CPT) [E]

Bids are anchored to the medians in §2.1. Start at roughly the median, then raise keywords with TTR ≥8% and CR ≥55% by 15–20% every 3–4 days, and cut ones with TTR <4%.

| Campaign | US | CA | UK+IE+AU+NZ | DE/FR/NL/JP (week 3+) |
|---|---|---|---|---|
| Brand | $0.60 | $0.40 | $0.50 | $0.30 |
| Category (exact) | $1.60–2.20 (hot flash / perimenopause / menopause tracker at the top) | $1.00–1.40 | $1.20–1.60 | DE $0.90–1.20, FR $0.70–1.00, NL $0.80–1.10, JP $0.90–1.20 |
| Competitor | $1.00–1.40 | $0.70 | $0.90 | $0.60 |
| Discovery | $0.90–1.20 | $0.70 | $0.80 | $0.60 |

**Daily caps, weeks 1–2 ($35/day total):** US: Brand $2, Category $14, Competitor $4, Discovery $4 · CA: Category $3, Discovery $1 · UK+IE+AU+NZ: Brand $1, Category $4, Competitor $1, Discovery $1.

Note: Q4 CPTs run highest (Search tab CPT went from $0.83 in Q3 to $1.23 in Q4 2025 [S: MobileAction]). Expect November–December to cost more, and January (New Year health intent) to be favorable [E].

### 3.5 Custom Product Page pairing

CPPs lift downloads ~23% on the same spend (TTR +12%, CR +10%) [S: Adapty, 1M+ ad groups]. AppTweak's US data shows 58.7% vs 55.5% CR [S]. **Warning from the same Adapty study:** a CPP can raise installs while *lowering trials* if the page promises something the paywall doesn't deliver, so judge CPPs on cost per trial, not CR. Apple allows 70 CPPs per app (since October 2025), CPPs can carry their own organic keywords (since July 2025), and from iOS 18 they can deep-link [S: Apple, Moburst, Adapty].

| CPP | Paired ad group | Lead screenshot / message | Deep link |
|---|---|---|---|
| **HotFlash** | Category › HotFlash (+ UK "hot flush" variant) | "One tap from Lock Screen or Apple Watch" + heat map | Surge button / Today |
| **NightSweats** | Category › NightSweats | Night Watch Live Activity: "a button that's there at 3am" | Night Watch explainer (not the arming link) |
| **Doctor** | Category › Doctor/HRT, Tracker | Clinician PDF: "Walk in with notes" | Visit-prep screen |
| **Peri** | Category › Peri | Cycle-phase patterns, "is this perimenopause?" framing (non-diagnostic) | Patterns sample preview |
| **Private** | Competitor | "No account. No cloud. Your data never leaves your iPhone." | Default |
| Localized versions of HotFlash + Doctor | DE, FR, JP, NL campaigns | Native-language screenshots | — |
| Partner CPPs (one per newsletter/creator) | not used in Apple Ads | Partner's own framing | — |

Paywall headline alignment: the Doctor CPP should lead to "Walk in with notes" (already the appointment-path headline in the spec).

---

## 4. What drives "Top Grossing" in Health & Fitness

### 4.1 Conversion benchmarks that matter for MenoMap

| Metric | Benchmark | Source / date |
|---|---|---|
| Trial starts on install day | **82%** of all trial starts | RevenueCat SOSA 2025 (2024 data) |
| Download → trial, H&F | Median 9.8% (high-priced apps) vs 4.3% (low-priced) | RevenueCat SOSA 2025 |
| Download → trial, H&F (other source) | ~5–7% median; top 5% 12–15% | Adapty 2026 via aggregator (**low confidence**) |
| Trial → paid, H&F | **39.9% median, 68.3% top decile** (RevenueCat 2025); 62% (Adapty 2026) | Vendor samples differ |
| Trial length effect | 17–32-day trials convert 42.5% vs 25.5% for ≤4-day | RevenueCat SOSA 2025 |
| Hard paywall vs freemium, H&F D35 download→paid | **12.1% vs 2.18%** | RevenueCat SOSA 2025 |
| Value moment before paywall | 1.5–2× higher trial-to-paid than an immediate hard paywall (RevenueCat); 2.1× higher trial start (Adapty) | Vendor |
| Revenue per install, H&F | 14-day median $0.44 (P75 $1.31); 60-day median $0.63 (P90 $4.19) | RevenueCat SOSA 2025 |
| Install LTV, H&F | $1.21 (highest category); subscriber annual LTV $45.10 | Adapty 2026 |
| Annual-plan share, H&F | 61% of plans in 2025 (up from 51% in 2023) | Adapty 2026 |
| H&F refund rate | 4.71% (2nd-highest category) | RevenueCat SOSA 2025 |

**Implication for MenoMap [E]:** MenoMap is freemium with the paywall never shown in session 1. Unless onboarding changes, expect **install → trial of ~2–5%** on paid traffic (below the 9.8% median for high-priced apps) and trial → paid of ~40–55% (the audience is older, intent is high, and trials are on yearly only). That gives ~1–2.5% of installs paying. At ~$42.50 net per yearly sub (15% Small Business Program commission), plus some lifetime/monthly/Visit Report revenue, **first-year revenue per paid install ≈ $0.50–1.30**. Against a US H&F CPI of ~$3.77 that is a **first-year ROAS of ~15–35%**, and only better in markets and keywords with cheap installs or unusually high intent.

**Options to test (product decisions, in order of expected impact):**
1. **A dismissible onboarding paywall**: shown after onboarding sets up the first value moment (e.g. after the user sets up their Lock Screen button or sees the sample heat map), with the close button visible. This keeps the "no countdowns, no data threats" rule. Could plausibly double install → trial [E, from the 82% day-0 statistic].
2. A **14-day trial** for paid-traffic CPPs, since longer trials convert better (RevenueCat). Test it; it delays the signal by a week.
3. Make the **Visit Report ($4.99)** visible early for "doctor"-intent keywords. It is a lower-friction first purchase.

### 4.2 Rank thresholds

**No reliable public source gives revenue-per-rank for Health & Fitness in 2025–2026.** The widely quoted figures (e.g. "$47k/day for top-10 grossing", "rank #871 ≈ $700/day") date from 2013–2014 and cover all categories. They are **stale; don't use them**. Apple's grossing chart weights recent revenue (one big day can move a rank [S: AppRadar 2026]). Each annual subscription counts its full price on the day it bills, so trial conversions from a launch week land together about 7 days later.

**Estimates [E, low confidence; build ranges from AppCurrents' modeled ranges and the AppBrain chart of 2026-10-08]:**
- US H&F grossing #1–5: ~$50k–300k/day (AppCurrents models #1–5 at $0.8–9M/month worldwide).
- US H&F grossing #17 (Clue): Clue is modeled at $230k–1.5M/month worldwide, so the US share is perhaps $3–20k/day.
- **US H&F #100: ~$2–6k/day gross. #200: ~$0.8–2.5k/day.**
- **UK H&F #100: ~$300–1,000/day. #200: ~$150–400/day.** Smaller English storefronts (IE, NZ) are lower still.
- Top **Free** H&F, US #100: ~1,500–4,000 downloads/day. UK #100: ~200–600/day.

**Implication:** at $20–100/day of ad spend with ROAS below 1, paid UA alone won't chart MenoMap in US top grossing. A **UK/AU/IE Top Free H&F** appearance is plausible on a strong launch day or after an Apple feature. Chart rank is a by-product, not a KPI. Optimize for cost per paying user.

---

## 5. Which storefronts give the cheapest installs relative to revenue

There is no country-level menopause benchmark, so this crosses AppTweak's 2025 all-category Search Results CPI with MenoMap's price bands from `MARKETS.md`. **"Price per $1 of CPI"** = (local yearly price ÷ US yearly price) ÷ CPI, a rough revenue-per-cost index that **ignores country differences in conversion**. Those differences are real: North America leads subscription conversion, and the US alone is ~49% of global in-app subscription revenue [S: Adapty 2026; RevenueCat].

| Market | Search Results CPI (all-cat, 2025) | MenoMap band | Index (higher = better) | Read [E] |
|---|---|---|---|---|
| United States | $4.06 (H&F $3.77) | A | 0.25–0.27 | Most volume and highest willingness to pay, but the most expensive auction. Keep it, but on tight exact-match keywords. |
| United Kingdom | $2.60 | A | 0.38 | **Strong.** Mainstream menopause conversation (HRT, "hot flush"), and Balance and Health & Her are UK-born, which validates demand. |
| Canada | $2.24 | A | 0.45 | **Strong.** "Hot flash" wording, US-like conversion [E]. |
| Australia | $2.19 | A | 0.46 | **Strong.** "Hot flush", high iPhone share. |
| Ireland / New Zealand | n/a (small) | A | likely ≈ UK/AU | Bundle with the UK campaign. |
| Germany | $2.14 | A | 0.47 | **Best non-English bet.** Full price band, CPI half the US, and the app is localized. |
| France | $1.78 | A | 0.56 | Cheap with a full price band. Conversion is unknown; test in week 3+. |
| Netherlands / Nordics | ~$1–2 (Adapty: Norway CPT $0.76) | A | ~0.5+ | Good test markets with high iPhone share. |
| Japan | $2.57 | A | 0.39 | 更年期 is a large, well-known topic. Japanese CR is lowest (46%). Test week 6+. |
| South Korea | $1.84 | B (0.75) | 0.41 | Medium. |
| Brazil / Mexico | $1.05 / $1.10 | C (0.5) | ~0.46–0.48 | Cheap installs, but expect much lower pay rates [E]. Organic only for now (`MARKETS.md` Tier 3). |
| India | $0.89 | D (0.35) | 0.39 | Volume without revenue. Skip paid. |

**Recommendation:** start in **US + CA + UK/IE + AU/NZ**. In week 3, add **Germany (DE/AT/CH)** and **France**, then NL and the Nordics. Add Japan around week 6 if the European tests clear the thresholds. Keep Tier 3 organic. Cheap high-volume markets are good only for a short burst to lift Top Free rank in one storefront, and that isn't worth it at this budget.

---

## 6. Phased plan, KPIs and kill/scale rules

### Unit economics used for thresholds [E]
- Net yearly price (US, after Apple's 15%): **$42.49**. Lifetime: $84.99. Monthly: $8.49.
- Value of a trial ≈ trial→paid × first-year net ≈ 0.45 × $42.49 ≈ **$19** (first year). Adding ~50% year-2 renewal [S: RevenueCat annual retention 48–54%] gives ≈ **$29** over 2 years.
- So: **target cost per trial ≤ $20** (about one-year payback), **tolerable up to $30**. **Target cost per paying subscriber ≤ $45, tolerable up to $65.**
- Volume reality: $35/day at a ~$3 blended CPI ≈ 12 installs/day; at 3–5% trial ≈ 0.4–0.6 trials/day ≈ **6–8 trials in 2 weeks**. That's too few to judge on trials, so **weeks 1–2 are judged on top-of-funnel metrics** and trial/paid gates apply from week 3 on.

### Weeks 1–2 (launch window, Oct 11–25, overlapping World Menopause Day Oct 18): $30–40/day, about $500 total
- Apple Ads Search Results only: US, CA, UK+IE+AU+NZ; 4 campaign types; caps per §3.4. Create the 4 English CPPs (HotFlash, NightSweats, Doctor, Private) before launch if possible.
- Free work in parallel: the In-App Event (already drafted); clinic-code outreach (10 practices); Reddit participation; contacting 6–10 micro creators and 3–4 newsletters for weeks 3–6 (get media kits).
- Rob setup (no spend): connect Apple Ads to RevenueCat (Advanced, Sign in with Apple); create `ct` tokens and offer codes for each future partner.
- **KPIs:** TTR (target ≥7%), tap→install CR (≥50%), CPT vs bid, CPI (US ≤$4, UK ≤$3, CA/AU ≤$2.50), and the first trials by keyword.
- **Gates at day 14 (per keyword, once it has ≥$40 spend or ≥40 taps):** pause if TTR <3% or CR <35%. Cut the bid 25% if CPI is >1.5× the market target. Raise the bid 15–20% if TTR ≥8% and CR ≥55% with impression share limited.

### Weeks 3–6: $50–75/day, about $1,800 total
- Apple Ads (~$40–55/day): move budget to keywords with trials. Add DE/AT/CH and FR (Category + Discovery, localized CPPs), ~$10–15/day combined. Promote new exact keywords from Discovery search terms.
- Creators and newsletters (~$150–250/week as flat fees): 3–5 micro creators ($150–300 each) plus 1 newsletter ($150–500). Each gets its own code, `ct` link and (ideally) CPP.
- Optional product test: the dismissible onboarding paywall (§4.1).
- **KPIs:** install→trial by keyword (RevenueCat, filtered on Apple Ads keyword), **cost per trial**, early trial→paid (from day 7 after trial start), and per-partner redemptions and `ct` downloads.
- **Kill/scale per Apple Ads keyword (after ≥$60 spend or ≥25 installs):**
  - **Scale** (+20% bid/budget): cost per trial ≤ $20.
  - **Hold / optimize CPP**: $20–35.
  - **Pause**: > $35, or **0 trials after 40 installs**.
  - Existing rule from `MARKETS.md` still applies at ~100 installs: pause if revenue per install < CPI *and* the projected 12-month ROAS is below 60%.
- **Partner rule:** renew a creator or newsletter if (installs from the `ct` token + code redemptions) give a cost per trial-equivalent ≤ $30. Otherwise drop them.

### Weeks 7–12: $75–100/day, about $3,600 total
- Apple Ads (~$50–65/day): scale winners. Add NL, Nordics and JP if DE/FR clear the gates. Test **Product Pages** placement at $5–8/day for 2 weeks (kill if cost per trial > $35). Consider **Maximize Conversions** only on a campaign doing ≥5 installs/day with a target CPA set at the current blended CPI.
- Creators/newsletters (~$15–20/day equivalent): repeat the winners. Use their videos as creatives.
- **Meta test (optional, ~$25–35/day for 3 weeks)**, only after shipping SKAN support (Info.plist IDs + native CV updates, with CV = trial start / purchase bits). Advantage+ app campaign, Tier 1 English, optimizing for installs, 3–5 creator videos. **Kill** if blended non-Apple-Ads trial cost > $35 after $500, or IPM < 2 (Adapty's rule of thumb).
- **KPIs:** cost per paying subscriber (target ≤ $45), 30-day ROAS from RevenueCat (proceeds ÷ spend for Apple Ads cohorts; target ≥ 35–50% at day 30 for yearly-heavy cohorts, which implies ~100% at 12 months), trial→paid (≥40%), refund rate (<5%), and blended paid share (all new payers ÷ total spend).
- **Scale rule for the whole program:** if 30-day Apple Ads ROAS ≥ 50% *and* trial→paid ≥ 40% for 2 consecutive weeks, raise the total budget by 25% per week up to $150–200/day. If 30-day ROAS stays < 25% after week 8, **cap spend at $20–30/day on brand + top exact keywords** and put effort into the paywall and organic/clinic channels.

### KPI dashboard (weekly, by keyword/market)
| Funnel step | Source | Target |
|---|---|---|
| CPT, TTR, tap→install CR, CPI | Apple Ads | CPT ≤ bid, TTR ≥7%, CR ≥50%, CPI per §6 |
| Install → trial | RevenueCat (Apple Ads keyword filter) | ≥4% now; ≥8% if the onboarding paywall ships |
| Cost per trial | Spend ÷ trials | ≤ $20 (kill > $35) |
| Trial → paid | RevenueCat | ≥ 40% |
| Cost per payer | Spend ÷ new payers | ≤ $45 (tolerable $65) |
| 30-day ROAS | RevenueCat proceeds ÷ spend | ≥ 35–50% |
| Partner channels | App Store Connect campaign (`ct`) + offer-code redemptions | ≤ $30 per trial-equivalent |

---

## 7. Uncertainties and caveats

- **Category benchmarks aren't menopause benchmarks.** Menopause keywords may be cheaper than the H&F median (a niche with few large bidders) or pricier (about ten indie trackers launched in 2025–26 and probably bid on the same terms). Two weeks of real data will settle it.
- **Vendor bias:** AppTweak, SplitMetrics, MobileAction, Adapty and RevenueCat all sell tools to app marketers, and their samples skew to apps already spending on ads. Superads, Webtonic, semnexus, trysonar and aggregator stat sites are lower-quality sources, marked as such above.
- **Stale or contested figures:** the top-grossing revenue thresholds (all estimates), TikTok CPI ($1.20–2.40, low confidence), Reddit subscriber counts (snapshot date unclear), and Today tab data (2024).
- **Platform policy changes fast.** Meta health-data enforcement expanded through 2025–26, and Apple changed AdServices on 2026-09-01. Recheck before each new channel.
- **Not verified:** Midday's current App Store availability; the exact Meta SKAdNetwork IDs to add (take them from Meta's own docs at implementation time); whether Meta classifies MenoMap as a restricted health advertiser (likely, so assume yes); and the claimed $100 first-time Apple Ads credit (trysonar; check in the Apple Ads UI).
- Nothing was signed up for, created, or purchased in producing this report.

---

## Sources

Apple Ads benchmarks and features
- AppTweak, Apple Ads benchmarks 2026 (2025 data; US H&F CPT/CPI/CR/TTR; country tables): https://www.apptweak.com/en/aso-blog/apple-ads-benchmarks
- SplitMetrics, Apple Ads Search Results Benchmarks 2026: https://splitmetrics.com/apple-ads-search-results-benchmarks-2026/ and https://splitmetrics.com/blog/apple-search-ads-cost
- MobileAction, Apple Ads 2026 Benchmark Report, Product Page ads: https://www.mobileaction.co/report/apple-ads-2026-benchmark-report/product-page-ads/
- MobileAction, Search tab ads (2025): https://www.mobileaction.co/report/apple-ads-2026-benchmark-report/search-tab-ads/
- MobileAction, Today tab ads (2024 data): https://www.mobileaction.co/report/apple-search-ads-2025-benchmark-report/today-tab-ads/
- Adapty, Apple Ads benchmarks for subscription apps 2026: https://adapty.io/apple-ads-for-subscription-apps/
- Adapty, Apple Search Ads in 2026 (placements, Maximize Conversions): https://adapty.io/blog/apple-search-ads/
- Adapty, Do Apple Ads custom product pages work?: https://adapty.io/blog/do-apple-ads-custom-product-pages-work/
- Trysonar, Apple Search Ads cost (indie budgets; vendor blog): https://trysonar.app/blog/apple-search-ads-cost
- NeoAds, Apple Ads Maximize Conversions guide (2026): https://neoads.substack.com/p/apple-ads-maximize-conversions
- ppc.land, Apple expands search ads placements 2026: https://ppc.land/apple-expands-app-store-search-ads-with-multiple-placements-arriving-in-2026/
- Zoomd, Apple to expand App Store search ads from March 2026: https://www.zoomd.com/apple-to-expand-app-store-search-ads-from-march-2026-mobile-marketing-takeaways-for-app-advertisers/
- Macworld, more ads in the App Store: https://www.macworld.com/article/3041228/get-ready-for-more-ads-in-the-app-store.html
- Apple Advertising Policies: https://ads.apple.com/policies
- Apple Ads, Modify audience settings: https://ads.apple.com/app-store/help/ad-groups/0021-modify-audience-settings
- Apple Ads, Ad variations best practices: https://ads.apple.com/app-store/best-practices/ad-variations
- AppsFlyer bulletin, Apple Ads timestamps / age-gender attribution change (Sep 2026): https://support.appsflyer.com/hc/en-us/articles/50216486847249-Bulletin-Apple-Ads-adds-timestamps-to-all-attribution-claims
- Apple AdServices API v4 (2026-09-01): https://ads.apple.com/adsdam/cn/zh_cn/documents/help/0028-apple-ads-attribution-api/2026-09-01/AdServices-API-v4.pdf
- RevenueCat, Apple Search Ads integration docs: https://www.revenuecat.com/docs/integrations/attribution/apple-search-ads
- App Store Connect Help, campaign links / manage campaigns: https://developer.apple.com/help/app-store-connect/view-app-analytics/manage-campaigns
- mbadv.agency, Apple Ads targeting (78% volume claim; single source): https://www.mbadv.agency/apple-ads/apple-ads-targeting-and-keywords

Subscription benchmarks and charts
- RevenueCat, State of Subscription Apps 2025: https://revenuecat.com/state-of-subscription-apps-2025
- RevenueCat, State of Subscription Apps 2026: https://revenuecat.com/state-of-subscription-apps/
- Adapty, State of In-App Subscriptions 2026: https://adapty.io/state-of-in-app-subscriptions-report/
- ppc.land on Adapty 2026 report: https://ppc.land/95-of-app-subscription-revenue-goes-to-top-10-adaptys-2026-benchmark-report/
- AppBrain, US App Store top grossing Health & Fitness (2026-10-08): https://www.appbrain.com/stats/appstore-rankings/top_grossing/health_and_fitness/us
- AppCurrents, Health & Fitness revenue estimates (modeled): https://appcurrents.com/categories/health-fitness
- AppRadar, top grossing apps 2026: https://appradar.com/blog/top-grossing-apps-app-store
- AppleInsider (2013, stale): https://forums.appleinsider.com/discussion/158288

Meta, TikTok, Google, Pinterest, Reddit, Microsoft
- Freshpaint, Meta data restrictions for healthcare: https://freshpaint.io/blog/meta-data-restrictions
- Ours Privacy, Meta changes (Jan 2025): https://oursprivacy.com/meta
- PixelFlow, Meta health & wellness restrictions: https://docs.pixelflow.so/what-are-meta-s-health-and-wellness-restrictions-and-how-do-they-affect-tracking-ce3t3
- Search Engine Land, Meta removes sensitive targeting (2022): https://searchengineland.com/?p=378095
- Accelerated Digital Media, 2026 health ad policies on social: https://www.accelerateddigitalmedia.com/insights/guide-to-social-media-health-ad-restrictions-2026/
- Linkrunner, Meta SKAN setup without Meta SDK: https://docs.linkrunner.io/features/meta-skan-setup
- AppsFlyer, SKAN interoperation with Meta: https://support.appsflyer.com/hc/en-us/articles/360017095198
- Adapty, First $10K on Meta ads for subscription apps (Feb 2026): https://adapty.io/blog/markdown/first-10k-meta-ads-subscription-apps.md
- Superads, Facebook CPI Wellness & Holistic Health US (tool data): https://www.superads.ai/facebook-ads-costs/cost-per-app-install/wellness-holistic-health/united-states
- NapoleonCat, US Facebook/Instagram demographics (Nov 2025): https://napoleoncat.com/stats/social-media-users-in-united_states_of_america/2025
- TikTok Ads Help, iOS 14+ measurement considerations: https://ads.tiktok.com/help/article/measurement-considerations-ios14?lang=en
- Google Ads Help, iOS App campaign measurement best practices: https://support.google.com/google-ads/answer/10384955
- Google Ads Help, SKAdNetwork reporting for iOS App campaigns: https://support.google.com/google-ads/answer/14892597
- Google Ads policy, Health in personalized advertising: https://support.google.com/adspolicy/answer/16701855
- Pinterest Help, app install ads (MMP requirement): https://help.pinterest.com/business/article/promoted-app-pins
- Pinterest CPM benchmarks 2026 (aggregator): https://www.hubfluence.io/resources/pinterest-cpm-rates
- ppc.land, Reddit SKAN 4.0 support: https://ppc.land/reddit-launches-skan-4-0-support/
- Webtonic, Health & wellness Reddit ads stats 2026 (agency blog): https://www.webtonic.io/blog/health-wellness-reddit-ads-statistics
- GummySearch, r/Menopause and r/Perimenopause: https://gummysearch.com/r/Menopause/ , https://gummysearch.com/r/Perimenopause
- Microsoft Advertising, App install ads: https://help.ads.microsoft.com/apex/index/3/en/56836
- semnexus, CPI benchmarks 2026 (low confidence): https://semnexus.com/cpi-benchmarks-app-category-platform-2026/

Competitors, creators, newsletters, podcasts
- MenoMap App Store listing: https://apps.apple.com/app/menomap-menopause-tracker/id6817484445
- Balance: https://apps.apple.com/us/app/id1503345959
- Caria: https://apps.apple.com/us/app/id1477621356
- Perry: https://apps.apple.com/us/app/id1544428724
- Stella: https://apps.apple.com/us/app/id1577904186 and https://onstella.com/stella-app
- Evia: https://apps.apple.com/app/id1582336046
- Health & Her: https://similarweb.com/app/apple/1519199698
- Midday (Mayo Clinic / Lisa Health): https://newsnetwork.mayoclinic.org/discussion/lisa-health-launches-midday-an-app-leveraging-ai-to-personalize-the-menopause-journey-in-collaboration-with-mayo-clinic
- Flo for Perimenopause (Jul 2025): https://flo.health/newsroom/flo-for-perimenopause-is-launching-to-empower-the-1-billion-women-who-experience-perimenopause-without-the-support-they-deserve
- Clue Perimenopause mode: https://support.helloclue.com/hc/en-us/articles/13059487439261-What-s-Clue-Perimenopause-mode
- New indie trackers: MidLife https://apps.apple.com/app/midlife/id6769793211 · Aster https://apps.apple.com/app/id6777118642 · Flare https://apps.apple.com/app/id6776996876 · MenoWise https://apps.apple.com/app/id6759270031
- Reletter newsletter listings: https://reletter.com/publications/hotflash-inc · https://reletter.com/publications/my-menopause-medicine · https://reletter.com/publications/the-vajenda
- Hotflash inc podcast: https://thehotflashincpodcast.buzzsprout.com/2055642
- Dr Streicher podcast: https://www.drstreicher.com/podcast
- Podder, podcast CPM rates 2026: https://www.podderapp.com/post/podcast-cpm-rates-2026
- iqfluence, menopause influencers: https://iqfluence.io/public/top-influencers/menopause-influencers
- HypeAuditor, @menopause_doctor: https://hypeauditor.com/instagram/menopause_doctor/
- Collabstr, menopause / perimenopause creators: https://collabstr.com/top-influencers/menopause , https://collabstr.com/top-influencers/perimenopause
- Collabstr, Instagram influencer costs 2026: https://collabstr.com/blog/instagram-influencer-marketing
- Menopause epidemiology (DelveInsight via PR Newswire): https://prnewswire.co.uk/news-releases/menopause-market-to-grow-rapidly-at-a-cagr-of-1-2-by-2032--predicts-delveinsight-301924184.html
