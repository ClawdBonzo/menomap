# MenoMap — Markets, Languages & Pricing

Draft 2026-09-29, for Rob's review. Companion to `Docs/SPEC_ADDITIONS.md`.

## Availability rule

**Every App Store storefront except:**
| Storefront | Why |
|---|---|
| Russia | Standing GW Labs rule (payments and payouts) |
| China mainland | **Off** (Rob, 2026-09-29). There's no ICP filing, and Apple requires one for China distribution. zh-Hans stays localized for Singapore, Malaysia and the diaspora. |

Being in a storefront costs nothing: the app is free to download, prices are per territory, and every string falls back to the nearest language. So "good fit" decides **how much effort a market gets** (localization, ASO, ads), not whether it's available at all.

Legal posture per region: a wellness tracker with no diagnosis, no treatment advice, and no server holding health data. EU/EEA/UK get an explicit health-data consent step in onboarding (GDPR Art. 9 style, even though processing is on-device). South Korea and Japan: wellness positioning with no disease claims, same as the store copy rules. EU sales require DSA **trader** status (Rob to confirm on the account).

## Market tiers

**Tier 1 — full localization, ASO and Apple Ads at launch** (high iPhone share, high willingness to pay, English-speaking menopause conversation):
- United States, Canada: "hot flash"
- United Kingdom, Ireland, Australia, New Zealand: **"hot flush"**

**Tier 2 — full localization and per-storefront ASO; Apple Ads after the Tier 1 data is in:**
- Germany, Austria, Switzerland
- Netherlands, Belgium
- France
- Sweden, Denmark, Norway, Finland
- Japan
- South Korea
- Spain, Italy
- Israel
- Taiwan, Hong Kong
- Singapore
- UAE, Saudi Arabia, Qatar, Kuwait

**Tier 3 — full localization, purchasing-power pricing, organic only:**
- Brazil, Portugal
- Mexico and Spanish-speaking Latin America
- Poland, Czechia, Slovakia, Hungary, Romania, Croatia, Greece, Ukraine
- Türkiye
- Thailand, Vietnam, Indonesia, Malaysia, Philippines
- India, South Africa

**Everything else:** available, with the nearest UI language and English store metadata.

## Languages at launch (~32 UI languages plus English regional variants)

These are the WishLock pipeline languages, re-chosen for menopause fit. Symptom terms are **a starting glossary for translators to confirm**, not final.

| Code | Language | Hot flash term (glossary seed) | Menopause term |
|---|---|---|---|
| en | English (US base) | hot flash | menopause |
| en-GB (+ AU, NZ, IE, IN, ZA) | English (UK) | **hot flush** | menopause |
| de | German | Hitzewallung | Wechseljahre |
| fr | French (+ fr-CA review) | bouffée de chaleur | ménopause |
| es | Spanish (Spain) | **sofoco** | menopausia |
| es-419 | Spanish (Latin America) | **bochorno** | menopausia |
| pt-BR | Portuguese (Brazil) | fogacho / onda de calor | menopausa |
| pt-PT | Portuguese (Portugal) | afrontamento | menopausa |
| it | Italian | vampata di calore | menopausa |
| nl | Dutch | opvlieger | overgang |
| sv | Swedish | värmevallning | klimakteriet |
| da | Danish | hedetur | overgangsalder |
| nb | Norwegian | hetetokt | overgangsalder |
| fi | Finnish | kuumat aallot | vaihdevuodet |
| pl | Polish | uderzenie gorąca | menopauza |
| cs | Czech | návaly horka | menopauza / přechod |
| sk | Slovak | návaly tepla | menopauza |
| hu | Hungarian | hőhullám | menopauza / változókor |
| ro | Romanian | bufeu | menopauză |
| hr | Croatian | valunzi | menopauza |
| el | Greek | εξάψεις | εμμηνόπαυση |
| uk | Ukrainian | припливи | менопауза |
| tr | Turkish | sıcak basması | menopoz |
| he | Hebrew (RTL) | גל חום | גיל המעבר |
| ar | Arabic (RTL) | الهبّات الساخنة | سن انقطاع الطمث |
| ja | Japanese | ホットフラッシュ | 更年期 |
| ko | Korean | 안면홍조 | 갱년기 |
| zh-Hans | Chinese (Simplified) | 潮热 | 更年期 |
| zh-Hant | Chinese (Traditional) | 熱潮紅 | 更年期 |
| th | Thai | ร้อนวูบวาบ | วัยหมดประจำเดือน |
| vi | Vietnamese | bốc hỏa | mãn kinh |
| id | Indonesian | hot flash / rasa panas | menopause |
| ms | Malay | kepanasan badan | menopaus |
| hi | Hindi | हॉट फ्लैश | रजोनिवृत्ति |

Build-time checks:
- iOS may not fall back from en-AU/en-NZ/en-IN to en-GB strings. If it doesn't, ship them as explicit copies.
- Store metadata goes to every App Store metadata locale these cover (about 40, the WishLock pattern), with UK/AU store copy using "hot flush".

## Per-locale details handled in code

- **Paper size:** Letter for US, CA, MX, PH and CL; A4 everywhere else. The user can override it.
- **Emergency number:** from a table verified against official sources at build time (e.g. 911, 999/112 UK, 112 EU, 000 AU, 111 NZ, 119 JP/KR, 101 IL ambulance, 997 SA ambulance, 998 UAE ambulance, 120 CN). Any country not verified shows "your local emergency number".
- **Temperature:** °C or °F from the locale, for wrist-temperature context.
- **Learn sources:** a national body where one is verified, otherwise the International Menopause Society.
- **Default voice:** Wry or Straight per locale (SPEC_ADDITIONS §6); the translator confirms.
- **Calendar:** Gregorian day keys everywhere; first day of the week from the locale.

## Pricing by territory (targets; exact Apple price points chosen at Milestone J)

| Band | Markets | Monthly | Yearly (7-day trial) | Lifetime | Visit Report |
|---|---|---|---|---|---|
| A (100%) | US, CA, UK, IE, AU, NZ, the Nordics, CH, DE, AT, NL, BE, FR, JP, SG, IL, the Gulf | $9.99 | $49.99 | $99.99 | $4.99 |
| B (~75%) | ES, IT, PT, KR, TW, HK, CZ, PL, GR, HR, SK, HU | ~$7.49 | ~$37.99 | ~$74.99 | ~$3.99 |
| C (~50%) | BR, MX, LatAm, TR, RO, UA, ZA, MY, TH | ~$4.99 | ~$24.99 | ~$49.99 | ~$2.49 |
| D (~35%) | IN, ID, VN, PH, EG, PK, and other low-purchasing-power storefronts | ~$3.49 | ~$17.99 | ~$34.99 | ~$1.49 |

Local prices are set to the nearest Apple price point in local currency, using the same equalization method as the WishLock and Visited per-territory pricing.

## Apple Ads (proposal, confirmed at Milestone J)

- **Tier 1 only in month 1.**
- **Keywords:** brand; "menopause app"; "menopause tracker"; "hot flash" (US/CA) or "hot flush" (UK/AU/NZ/IE); "perimenopause"; competitor names (Balance, Caria, Midday).
- **Rule:** pause a keyword after about 100 installs if revenue per install is below cost per install (the Visited rule).
