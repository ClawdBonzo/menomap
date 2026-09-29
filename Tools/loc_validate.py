#!/usr/bin/env python3
"""Validates one translated language file against the English source.

Usage:  python3 Tools/loc_validate.py Localization/out/de.json
Exit code 0 = clean. Every problem is printed with the string id so it can be fixed.
"""
import json, pathlib, re, sys
from collections import Counter

ROOT = pathlib.Path(__file__).resolve().parent.parent
SOURCE = json.loads((ROOT / "Localization/source/strings_en.json").read_text())

PLURALS = {
    "one_other": ["ca", "da", "de", "el", "es", "es-419", "fi", "fr", "hi", "hu", "it", "nl", "nb", "pt-BR", "pt-PT", "sv", "tr", "en-GB"],
    "other": ["id", "ja", "ko", "ms", "th", "vi", "zh-Hans", "zh-Hant"],
    "slavic": ["cs", "sk", "pl", "ru", "uk"],
    "few": ["hr", "ro"],
    "he": ["he"],
    "ar": ["ar"],
}
REQUIRED = {
    "one_other": {"one", "other"}, "other": {"other"}, "slavic": {"one", "few", "many", "other"},
    "few": {"one", "few", "other"}, "he": {"one", "two", "other"}, "ar": {"zero", "one", "two", "few", "many", "other"},
}
ALLOWED_EXTRA = {"zero", "one", "two", "few", "many", "other"}
PLACEHOLDER = re.compile(r"%(?:(\d+)\$)?(lld|@|d|ld|f|%)")

# Chinese and Japanese set full-width punctuation next to ideographs and kana: "凭证据，不凭感觉。" never "凭证据,不凭感觉."
FULL_WIDTH_LANGUAGES = {"ja", "zh-Hans", "zh-Hant"}
CJK = r"[぀-ヿ㐀-䶿一-鿿豈-﫿]"
HALF_WIDTH_NEXT_TO_CJK = re.compile(rf"{CJK}[,;:?()]|[,;:?()]{CJK}|{CJK}\.(?!\d)")


def check_full_width(language, where, text, problems):
    if language in FULL_WIDTH_LANGUAGES:
        match = HALF_WIDTH_NEXT_TO_CJK.search(text)
        if match:
            problems.append(f"{where} half-width punctuation next to CJK text ({match.group(0)!r}); use the full-width mark :: {text!r}"
                            if len(text) < 160 else f"{where} half-width punctuation next to CJK text ({match.group(0)!r}); use the full-width mark")


def required_categories(language: str) -> set:
    for group, languages in PLURALS.items():
        if language in languages:
            return REQUIRED[group]
    return {"one", "other"}


def kinds(text: str) -> Counter:
    return Counter(m.group(2) for m in PLACEHOLDER.finditer(text))


def check_placeholders(sid, english, text, problems, label=""):
    if kinds(english) != kinds(text):
        problems.append(f"[{sid}]{label} placeholders differ: EN {dict(kinds(english))} vs {dict(kinds(text))} :: {text!r}")
        return
    positions = [m.group(1) for m in PLACEHOLDER.finditer(text) if m.group(2) != "%"]
    if any(positions) and not all(positions):
        problems.append(f"[{sid}]{label} mixes positional and plain placeholders :: {text!r}")
    if all(positions) and positions:
        if sorted(int(p) for p in positions) != list(range(1, len(positions) + 1)):
            problems.append(f"[{sid}]{label} positional placeholders must be 1..{len(positions)} :: {text!r}")


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    path = pathlib.Path(sys.argv[1])
    try:
        data = json.loads(path.read_text())
    except Exception as error:  # noqa: BLE001
        print(f"INVALID JSON: {error}")
        return 1

    language = data.get("language", path.stem.split(".")[0])
    needed = required_categories(language)
    problems, warnings = [], []
    strings = data.get("strings", {})

    for item in SOURCE["strings"]:
        sid = str(item["id"])
        english = item["en"]
        value = strings.get(sid)
        if value is None:
            problems.append(f"[{sid}] missing :: {english!r}")
            continue
        if item.get("doNotTranslate"):
            if value != english:
                problems.append(f"[{sid}] must stay {english!r}, got {value!r}")
            continue

        forms = value if isinstance(value, dict) else {"": value}
        if isinstance(value, dict):
            unknown = set(value) - ALLOWED_EXTRA
            if unknown:
                problems.append(f"[{sid}] unknown plural categories {sorted(unknown)}")
            missing = needed - set(value)
            if missing:
                problems.append(f"[{sid}] plural needs {sorted(needed)}; missing {sorted(missing)}")
            if kinds(english).get("lld", 0) != 1:
                problems.append(f"[{sid}] plural object is only allowed for strings with exactly one %lld")
        elif item.get("plural"):
            problems.append(f"[{sid}] is a PLURAL string: return an object with {sorted(needed)}")

        for category, text in forms.items():
            label = f"[{category}]" if category else ""
            is_tense_list = item["key"].startswith("tense.")
            if not isinstance(text, str) or (not text.strip() and english.strip() and not is_tense_list):
                problems.append(f"[{sid}]{label} empty")
                continue
            # The tense lists are data: allowed to be empty, no placeholder or length checks.
            if is_tense_list:
                if text != text.lower():
                    problems.append(f"[{sid}] tense list must be lowercase")
                if "||" in text or text.startswith("|") or text.endswith("|"):
                    problems.append(f"[{sid}] tense list has an empty entry")
                continue
            check_placeholders(sid, english, text, problems, label)
            if item.get("article"):
                if english.count("**") != text.count("**"):
                    problems.append(f"[{sid}] article: bold markers differ (EN {english.count('**')}, got {text.count('**')})")
                if english.count("\n\n") != text.count("\n\n"):
                    problems.append(f"[{sid}] article: paragraph count differs (EN {english.count(chr(10)*2)+1}, got {text.count(chr(10)*2)+1})")
                if english.count("\n- ") != text.count("\n- "):
                    problems.append(f"[{sid}] article: bullet count differs")
            if "max" in item and len(text.replace("%lld", "00").replace("%@", "0000000")) > item["max"] + (7 if "%@" in text else 0):
                problems.append(f"[{sid}]{label} too long: {len(text)} > max {item['max']} :: {text!r} (EN {english!r})")
            elif "max" not in item and len(english) > 12 and len(text) > len(english) * 1.6 + 8:
                warnings.append(f"[{sid}]{label} long: {len(text)} vs EN {len(english)} :: {text!r}")
            if "!" in text or "！" in text or "¡" in text:
                problems.append(f"[{sid}]{label} contains an exclamation mark :: {text!r}")
            if english.endswith(" ") is False and text != text.strip():
                problems.append(f"[{sid}]{label} has leading/trailing whitespace")
            check_full_width(language, f"[{sid}]{label}", text, problems)

    extra = set(strings) - {str(i["id"]) for i in SOURCE["strings"]}
    if extra:
        problems.append(f"unknown ids: {sorted(extra)[:10]}")

    demo = data.get("demo", {})
    for item in SOURCE["demo"]:
        if not str(demo.get(item["id"], "")).strip():
            problems.append(f"[demo {item['id']}] missing")
        if isinstance(demo.get(item["id"]), str):
            check_full_width(language, f"[demo {item['id']}]", demo[item["id"]], problems)

    store = data.get("store", {})
    limits = SOURCE["store"]["_limits"]
    for field in ("name", "subtitle", "keywords", "promotionalText", "description", "whatsNew"):
        text = store.get(field, "")
        if not text.strip():
            problems.append(f"[store.{field}] missing")
        elif len(text) > limits[field]:
            problems.append(f"[store.{field}] {len(text)} chars; max {limits[field]} :: {text!r}" if len(text) < 200 else f"[store.{field}] {len(text)} chars; max {limits[field]}")
    for field in ("name", "subtitle", "promotionalText", "description", "whatsNew"):
        for line in store.get(field, "").splitlines():
            check_full_width(language, f"[store.{field}]", line, problems)
    for plan, entry in store.get("iap", {}).items():
        for part in ("name", "description"):
            if isinstance(entry, dict):
                check_full_width(language, f"[store.iap.{plan}.{part}]", str(entry.get(part, "")), problems)
    for number, text in store.get("screenshots", {}).items():
        check_full_width(language, f"[store.screenshots.{number}]", text.replace("*", ""), problems)
    if "MenoMap" not in store.get("name", ""):
        problems.append("[store.name] must contain MenoMap")
    keywords = store.get("keywords", "")
    if ", " in keywords or " ," in keywords:
        problems.append("[store.keywords] no spaces around commas")
    for url in ("https://gwlabs.app/menomap/privacy", "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"):
        if url not in store.get("description", ""):
            problems.append(f"[store.description] must keep {url}")
    iap = store.get("iap", {})
    for plan in ("monthly", "yearly", "lifetime", "visitReport"):
        entry = iap.get(plan, {})
        if len(entry.get("name", "")) == 0 or len(entry.get("name", "")) > limits["iap.name"]:
            problems.append(f"[store.iap.{plan}.name] missing or > {limits['iap.name']} chars :: {entry.get('name')!r}")
        if len(entry.get("description", "")) == 0 or len(entry.get("description", "")) > limits["iap.description"]:
            problems.append(f"[store.iap.{plan}.description] missing or > {limits['iap.description']} chars :: {entry.get('description')!r}")
    shots = store.get("screenshots", {})
    for number in map(str, range(1, 10)):
        text = shots.get(number, "")
        plain = text.replace("*", "")
        if not plain.strip():
            problems.append(f"[store.screenshots.{number}] missing")
        elif len(plain) > limits["screenshots"]:
            problems.append(f"[store.screenshots.{number}] {len(plain)} chars; max {limits['screenshots']} :: {text!r}")
        elif text.count("*") not in (2, 4):
            problems.append(f"[store.screenshots.{number}] wrap the accent word(s) in one or two pairs of asterisks :: {text!r}")
        if "!" in text or "！" in text:
            problems.append(f"[store.screenshots.{number}] contains an exclamation mark")

    if not data.get("glossary"):
        problems.append("glossary missing")

    for line in warnings[:15]:
        print("warn", line)
    for line in problems:
        print("FAIL", line)
    print(f"{path.name}: {len(problems)} problems, {len(warnings)} warnings")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
