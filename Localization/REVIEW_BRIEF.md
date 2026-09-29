# MenoMap — independent review brief

You are the **second pair of eyes**: a senior native-speaking editor with patient-information experience, reviewing
another translator's work for one language of MenoMap. You owe the translation no loyalty.

Read, in order:
1. `Localization/TRANSLATION_BRIEF.md` — product, medical rules, voice, glossary, technical rules. They bind you too.
2. `Localization/source/strings_for_translation.json` — the English source (strings, demo, store).
3. `Localization/out/<lang>.json` — the translation under review.

## Check every string (not a sample)
1. **Meaning in context** (`note`, `where`). Short labels hide mistakes: "Surge" (a hot flash or night sweat),
   "Visit" (clinician appointment tab), "You" (settings tab), "Hold" (breathing: hold the breath), "End" (stop the
   timer), "Taken"/"Skipped" (medication dose), "Calm"/"Hot" (heat-map legend), "Peak" (busiest time of day).
2. **Medical accuracy.** National patient-facing terms (hot flash vs hot flush region, night sweats, HRT/MHT,
   progestogen, perimenopause, bleeding after menopause, palpitations). Nothing diagnostic, nothing that
   recommends treatment, every hedge intact ("coincidence check, not proof", "your entries", "can't tell you why").
3. **Safety strings** (`"safety": true`): faithful and complete. Any drift is a must-fix.
4. **Native quality.** Stiff or calqued text → fix. Straight voice calm and warm; Wry voice genuinely funny in your
   language, never crude or mocking. If a wry line could offend in your culture, soften it.
5. **Placeholders with real values** (`%@` = a date, time, name, number; `%lld` = 0, 1, 2, 5, 11, 21, 30, 90).
   Grammar must survive every value; otherwise rephrase as "Label: value".
6. **Plurals:** exact CLDR categories, each form correct.
7. **Consistency:** one rendering per glossary term everywhere (UI, widgets, Watch, Lock Screen, Siri phrases,
   PDF, store, screenshots); one form of address; Apple's official localized platform terms and Health app name.
8. **Length:** every `max`; anything that would truncate on a small iPhone.
9. **Typography:** native quotes, spacing, full-width CJK punctuation, RTL for ar/he.
10. **Articles:** accurate patient education, markdown intact.
11. **Store:** limits (name 30, subtitle 30, keywords 100, promo 170, IAP name 30, IAP description 45,
    headlines 34), real local search terms, no competitor names, disclaimer paragraph complete, both URLs kept.

## How to change things
Change what is wrong, unnatural, inconsistent or risky; don't rewrite for taste (a good translation needs ~3–12%).
Never break placeholders, plural structure, ids or JSON.

## Output: a patch, checkpointed
Write only your changes to `Localization/review/<lang>.patch.json`:
```json
{"verdict": "one paragraph", "reviewedThrough": 440, "extrasReviewed": false,
 "strings": {"46": {"to": "…", "why": "…"}, "17": {"to": {"one": "…", "other": "…"}, "why": "…"}},
 "demo": {"d1": {"to": "…", "why": "…"}},
 "store": {"subtitle": {"to": "…", "why": "…"}, "screenshots.3": {"to": "…", "why": "…"}, "iap.yearly.name": {"to": "…", "why": "…"}},
 "glossary": {}, "doubts": []}
```
Update the file every ~150 strings (raise `reviewedThrough`), then the extras (set `extrasReviewed: true`).
After each update run `python3 Tools/loc_apply_review.py <lang>`; it must end with `0 problems`.
If a patch file already exists, a previous session was interrupted: continue from `reviewedThrough`.
