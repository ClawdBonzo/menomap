#!/usr/bin/env python3
"""Writes reviewed translations into every String Catalog (.xcstrings) of every MenoMap target.

    python3 Tools/loc_build_catalogs.py            # languages with Localization/out/<code>.reviewed.json
    python3 Tools/loc_build_catalogs.py --draft    # also unreviewed <code>.json (for layout checks only)

Also gives English its real plural variations ("1 surge" / "2 surges") for every plural string, creates missing
catalogs (InfoPlist, AppShortcuts, Watch complications) and lists every shipped language in the report.
"""
import json, pathlib, re, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SOURCE = json.loads((ROOT / "Localization/source/strings_en.json").read_text())
OUT = ROOT / "Localization/out"
PH = re.compile(r"%(?:(\d+)\$)?(lld|@|d|ld|f)")
SKIP_CATALOGS = {"MenoMapMessages/InfoPlist.xcstrings", "MenoMapWatch/InfoPlist.xcstrings",
                 "MenoMapWatchWidgets/InfoPlist.xcstrings", "MenoMapWidgets/InfoPlist.xcstrings"}


def positional_like(english: str, text: str) -> str:
    """If the English catalog value is positional (%1$@ %2$lld), give `text` the same numbering, in order."""
    positions = [m.group(1) for m in PH.finditer(english)]
    if not positions or not all(positions) or any(m.group(1) for m in PH.finditer(text)):
        return text
    it = iter(positions)
    return PH.sub(lambda m: f"%{next(it)}${m.group(2)}", text)


def unit(value: str) -> dict:
    return {"stringUnit": {"state": "translated", "value": value}}


def localization(value, english: str) -> dict:
    if isinstance(value, dict):
        return {"variations": {"plural": {cat: unit(positional_like(english, v)) for cat, v in value.items()}}}
    return unit(positional_like(english, value) if PH.search(value or "") else value)


def main() -> int:
    draft = "--draft" in sys.argv
    languages = {}
    for path in sorted(OUT.glob("*.json")):
        code = path.name.split(".")[0]
        if path.name.endswith(".reviewed.json") or (draft and code not in languages and not path.name.count(".") > 1):
            languages[code] = json.loads(path.read_text())
    catalogs = {}
    for item in SOURCE["strings"]:
        for cat in item["catalogs"]:
            if cat in SKIP_CATALOGS:
                continue
            path = ROOT / cat
            if cat not in catalogs:
                catalogs[cat] = json.loads(path.read_text()) if path.exists() else {"sourceLanguage": "en", "strings": {}, "version": "1.0"}
            entry = catalogs[cat]["strings"].setdefault(item["key"], {})
            if item.get("doNotTranslate"):
                entry["shouldTranslate"] = False
                continue
            locs = entry.setdefault("localizations", {})
            english = item["en"]
            if item.get("plural"):
                locs["en"] = localization({"one": item["enOne"], "other": english}, english)
            elif "${applicationName}" in item["key"] or cat.endswith("InfoPlist.xcstrings"):
                locs["en"] = unit(english)
            for code, data in languages.items():
                value = data["strings"].get(str(item["id"]))
                if value in (None, ""):
                    continue
                locs[code] = localization(value, english)
    for cat, data in catalogs.items():
        (ROOT / cat).write_text(json.dumps(data, ensure_ascii=False, indent=2, sort_keys=True) + "\n")
    # Screenshot demo data per language (names, medications, appointment), read by DemoData in DEBUG builds.
    demo = {"en": {d["id"]: d["en"] for d in SOURCE["demo"]}}
    demo.update({code: data.get("demo", {}) for code, data in languages.items()})
    (ROOT / "MenoMap/Resources/DemoLocalized.json").write_text(json.dumps(demo, ensure_ascii=False, indent=1) + "\n")
    print(f"{len(catalogs)} catalogs, languages: {', '.join(sorted(languages)) or '(none yet: English plurals only)'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
