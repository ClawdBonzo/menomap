#!/usr/bin/env python3
"""Builds Localization/source/strings_en.json from Xcode's exported XLIFF (every MenoMap target).

    xcodebuild -exportLocalizations -project MenoMap.xcodeproj -localizationPath build/loc -exportLanguage en
    python3 Tools/loc_build_source.py [--dry-run]

Each string gets a permanent numeric id, English text, a translator note, where it appears, the catalogs it
belongs to, a length budget where the layout is tight, a plural flag (with the English singular), and a
SAFETY flag for medical/safety copy (three-pass review: translator, reviewer, back-translation audit).
Also writes strings_for_translation.json, the compact view translators and reviewers read.
"""
import json, pathlib, re, sys, xml.etree.ElementTree as ET

ROOT = pathlib.Path(__file__).resolve().parent.parent
XLIFF = ROOT / "build/loc/en.xcloc/Localized Contents/en.xliff"
OUT = ROOT / "Localization/source/strings_en.json"
VIEW = ROOT / "Localization/source/strings_for_translation.json"
NS = {"x": "urn:oasis:names:tc:xliff:document:1.2"}

DO_NOT_TRANSLATE = {"MenoMap", "MenoMap Pro", "PRO", "%lld", "%lld / %lld", "%lld%%", "%lld, %@", "%lld. %@", "12a", "6a", "12p", "6p",
                    "gwlabs.app/menomap", "–", "·"}

# Strings with exactly one count: English singular (the catalog gets real one/other variations in every language).
ENGLISH_ONE = {
    "%@ in %lld days": "%@ in %lld day",
    "%@: %lld days": "%@: %lld day",
    "%@: %lld surges": "%@: %lld surge",
    "%lld days": "%lld day",
    "%lld days before": "%lld day before",
    "%lld days during": "%lld day during",
    "%lld fewer than the month before": "%lld fewer than the month before",
    "%lld more than the month before": "%lld more than the month before",
    "%lld hot flashes": "%lld hot flash",
    "%lld night sweats": "%lld night sweat",
    "%lld personal summers this week.": "%lld personal summer this week.",
    "%lld surges": "%lld surge",
    "%lld surges this week": "%lld surge this week",
    "%lld tonight": "%lld tonight",
    "Across your last %lld cycles, you logged %@ surges a day in the 3 days before your period started, compared with %@ on other days.":
        "Across your last %lld cycle, you logged %@ surges a day in the 3 days before your period started, compared with %@ on other days.",
    "Appointment in %lld days": "Appointment in %lld day",
    "Average %@ asleep over %lld nights (from Apple Health).": "Average %@ asleep over %lld night (from Apple Health).",
    "Bleeding after menopause recorded in Apple Health: %lld times.": "Bleeding after menopause recorded in Apple Health: %lld time.",
    "Found %lld surges from the last 90 days": "Found %lld surge from the last 90 days",
    "Imported %lld new surges.": "Imported %lld new surge.",
    "Longest calm stretch: %lld days": "Longest calm stretch: %lld day",
    "Longest calm stretch: %lld days.": "Longest calm stretch: %lld day.",
    "Longest calm stretch: %lld days. Frame it.": "Longest calm stretch: %lld day. Frame it.",
    "You have %lld Visit Report ready to use.": "You have %lld Visit Report ready to use.",
    "surges in %lld days": "surges in %lld day",
}

# Character budgets where the layout is tight.
MAX = {
    "Today": 12, "Week": 12, "Visit": 12, "You": 12,
    "7 days": 10, "30 days": 10, "90 days": 10, "Year": 10, "Story": 12, "Square": 12,
    "Hot flash": 16, "Night sweat": 16, "Mild": 12, "Noticeable": 12, "Strong": 12, "Very strong": 12, "Intense": 12,
    "Best value": 14, "Yearly": 14, "Monthly": 14, "Lifetime": 14, "Taken": 12, "Skipped": 12, "Yes": 8, "No": 8,
    "Calm": 9, "Hot": 9, "Peak": 12, "Typical": 12, "Calmest": 12, "Calm stretch": 16, "Longest": 16, "Shortest": 16,
    "End": 8, "Stickers": 14, "Heads-up": 14, "Surge": 12, "In": 8, "Hold": 8, "Out": 8, "Save": 12, "Done": 12,
    "Went well": 14, "Mixed": 14, "Didn't happen": 16, "Every day": 14, "Certain days": 14, "As needed": 14,
    "Night Watch": 18, "Quiet so far.": 22, "%lld tonight": 16, "Today: %lld": 16, "Surge · %lld": 14,
    "Already over": 18, "Unlock with Pro": 22, "Share": 12, "Close": 12, "Cancel": 12,
    "A4": 6, "US Letter": 12, "Hot flashes": 16, "Night sweats": 16, "Sleep": 14, "Mood": 14, "Energy": 14,
    "Brain fog": 16, "Stress": 14, "Check-in": 16, "Timeline": 16, "Records": 16, "Patterns": 16, "Experiments": 18,
}

NOTES = {
    "Today": "Tab bar item: today's screen.", "Week": "Tab bar item: stats for the week and longer.",
    "Visit": "Tab bar item: preparing for a clinician appointment.", "You": "Tab bar item: settings and profile.",
    "Surge": "A hot flash or night sweat (the app's umbrella word). Keep it short and neutral.",
    "End": "Button on the Lock Screen: stop the timer.", "In": "Breathing coach: breathe in.",
    "Hold": "Breathing coach: hold the breath.", "Out": "Breathing coach: breathe out.",
    "Calm": "Heat-map legend, low end.", "Hot": "Heat-map legend, high end.",
    "Mild": "Surge strength 1 of 5.", "Noticeable": "Surge strength 2 of 5.", "Strong": "Surge strength 3 of 5.",
    "Very strong": "Surge strength 4 of 5.", "Intense": "Surge strength 5 of 5.",
    "Story": "Share-card format: 9:16 vertical story.", "Square": "Share-card format: square.",
    "Taken": "Medication dose: taken today.", "Skipped": "Medication dose: skipped today.",
    "Went well": "Answer: how did the appointment go.", "Mixed": "Answer: how did the appointment go.",
    "Peak": "Stat label: the time of day with the most surges.", "Typical": "Stat label: typical surge length.",
    "Calmest": "Stat label: the calmest day.", "Calm stretch": "Stat label: most days in a row without a surge.",
    "12a": "Clock label: midnight (keep as is or use your 24h convention, e.g. 0h).",
    "6a": "Clock label: 6am.", "12p": "Clock label: noon.", "6p": "Clock label: 6pm.",
}

SAFETY_WORDS = ("diagnos", "clinician", "emergency", "bleeding", "not proof", "coincidence", "medical", "medicine",
                "chest pain", "fainting", "Heart sensations", "not medical treatment", "prescribe", "Not a diagnosis",
                "seek care", "feel unsafe", "doctor")


def write_view(payload):
    def line(item):
        slim = {"id": item["id"], "en": item["en"]}
        for f in ("note", "where", "max", "plural", "enOne", "doNotTranslate", "safety", "article"):
            if item.get(f):
                slim[f] = item[f]
        return json.dumps(slim, ensure_ascii=False, separators=(",", ":"))
    body = ",\n".join(line(i) for i in payload["strings"])
    demo = ",\n".join(json.dumps(i, ensure_ascii=False, separators=(",", ":")) for i in payload["demo"])
    VIEW.write_text(f'{{"strings":[\n{body}\n],\n"demo":[\n{demo}\n],\n"store":{json.dumps(payload["store"], ensure_ascii=False, indent=1)}}}\n')
    json.loads(VIEW.read_text())
    print(f"translator view -> {VIEW.relative_to(ROOT)} ({VIEW.stat().st_size // 1024} KB)")


def main():
    root = ET.parse(XLIFF).getroot()
    entries = {}
    for f in root.findall("x:file", NS):
        original = f.get("original", "")
        if not original.endswith(".xcstrings"):
            continue
        for unit in f.iter("{urn:oasis:names:tc:xliff:document:1.2}trans-unit"):
            key, _, variant = unit.get("id").partition("|==|")
            src = unit.find("x:source", NS)
            note = unit.find("x:note", NS)
            text = (src.text or "") if src is not None else ""
            e = entries.setdefault(key, {"key": key, "en": "", "note": "", "catalogs": set()})
            if not variant or variant.endswith("other"):
                e["en"] = text
            e["catalogs"].add(original)
            if note is not None and note.text and len(note.text) > len(e["note"]) and note.text != "No comment provided by engineer.":
                e["note"] = note.text

    sources = {p: p.read_text() for d in ("MenoMap", "Shared", "SharedCopy", "MenoMapWidgets", "MenoMapWatch", "MenoMapWatchWidgets", "MenoMapMessages")
               for p in (ROOT / d).rglob("*.swift")}

    def where(key):
        probe = re.split(r"%(?:\d\$)?(?:lld|@)", key)[0].strip()[:40]
        if len(probe) < 4:
            return ""
        return ", ".join(sorted({p.stem for p, t in sources.items() if probe in t})[:3])

    previous = json.loads(OUT.read_text()) if OUT.exists() else {}
    known = {i["key"]: i["id"] for i in previous.get("strings", [])}
    next_id = max([previous.get("nextId", 1)] + [v + 1 for v in known.values()])
    added, strings = [], []
    for key in sorted(entries, key=str.lower):
        e = entries[key]
        if not key.strip():
            continue
        if key not in known:
            known[key] = next_id
            added.append((next_id, key))
            next_id += 1
        en = e["en"] if e["en"].strip() else key
        note = e["note"] or NOTES.get(key, "")
        if "${applicationName}" in key:
            note = "Siri / Shortcuts phrase the user says. Must be a natural spoken command in your language and keep ${applicationName} exactly."
        item = {"id": known[key], "key": key, "en": en, "note": note, "where": where(key),
                "catalogs": sorted(e["catalogs"])}
        if key in DO_NOT_TRANSLATE or key in ("CFBundleDisplayName", "CFBundleName"):
            item["doNotTranslate"] = True
        if key in ENGLISH_ONE:
            item["plural"] = True
            item["enOne"] = ENGLISH_ONE[key]
        if key in MAX:
            item["max"] = MAX[key]
        if any(w.lower() in en.lower() for w in SAFETY_WORDS):
            item["safety"] = True
        if "\n\n" in en and len(en) > 600:
            item["article"] = True
        strings.append(item)
    strings.sort(key=lambda i: i["id"])
    demo = ["Dana", "Dr. Patel", "Estradiol gel", "Micronized progesterone", "1 pump", "Skin", "Every morning", "100 mg",
            "By mouth", "At bedtime", "Menopause review"]
    payload = {"nextId": next_id, "strings": strings,
               "demo": [{"id": f"d{i}", "en": t} for i, t in enumerate(demo, 1)],
               "store": json.loads((ROOT / "Localization/source/store_en.json").read_text())}
    retired = sorted(set(i["key"] for i in previous.get("strings", [])) - set(entries))
    if "--dry-run" not in sys.argv:
        OUT.write_text(json.dumps(payload, ensure_ascii=False, indent=1))
        write_view(payload)
    for n, k in added[:20]:
        print(f"NEW  [{n}] {k[:70]!r}")
    if len(added) > 20:
        print(f"… {len(added)} new")
    for k in retired:
        print(f"GONE {k[:70]!r}")
    print(f"{len(strings)} strings ({sum(1 for s in strings if s.get('plural'))} plural, {sum(1 for s in strings if s.get('safety'))} safety, "
          f"{sum(1 for s in strings if s.get('article'))} articles, {sum(1 for s in strings if s.get('max'))} with a budget)")
    missing_plural = [k for k in ENGLISH_ONE if k not in entries]
    if missing_plural:
        print("plural keys not found in source:", missing_plural)


if __name__ == "__main__":
    main()
