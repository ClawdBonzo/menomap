# MenoMap — safety back-translation audit (third pass)

You audit ONLY the safety-critical strings of one language: disclaimers, bleeding after menopause, emergencies,
medication questions, "not a diagnosis", "coincidence check, not proof". These are what keeps a user safe.

## Step 1 — blind (do not open any English file yet)
Open `Localization/review/<lang>.safety_blind.json` (translated text only). For each entry write a literal,
faithful English back-translation. Save it immediately as
`Localization/review/<lang>.audit.json` → `{"backTranslations": {"<id>": "…"}, "fixes": {}, "verdict": ""}`.

## Step 2 — compare
Now open `Localization/source/strings_for_translation.json` and compare each back-translation with the English
(`en`) of the same id (and the disclaimer paragraph of `store.description`). Flag ANY drift in meaning:
missing qualifier ("even once", "even light", "new, severe, or", "seek care now"), weakened or strengthened
instruction, added advice, diagnostic tone, a wrong medical term, ambiguity about who should act.
For each problem add a fix in the target language:
`"fixes": {"<id>": {"to": "corrected translation", "why": "what drifted"}}` (keep placeholders exactly).
Wording differences that keep the meaning are fine: do not fix style.

## Step 3
Set `"verdict"` (one paragraph: pass, or what you fixed). Run `python3 Tools/loc_apply_review.py <lang>`; it
applies review + audit fixes and must end with `0 problems`.
