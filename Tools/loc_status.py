#!/usr/bin/env python3
"""Where every language stands: translated, validated, reviewed.

    python3 Tools/loc_status.py
"""
import json, pathlib, subprocess, sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from loc_merge_parts import ROOT, status as parts_status  # noqa: E402
from loc_apply_review import is_complete  # noqa: E402

# Day-one languages, most valuable storefronts first.
PLAN = ["en-GB", "de", "fr", "es", "es-419", "ja", "ko", "it", "nl", "pt-BR", "pt-PT", "sv", "da", "nb", "fi", "pl", "zh-Hant",
        "zh-Hans", "he", "ar", "tr", "cs", "sk", "hu", "ro", "hr", "el", "uk", "th", "vi", "id", "ms", "hi"]


def validate(path: pathlib.Path) -> str:
    result = subprocess.run([sys.executable, str(ROOT / "Tools/loc_validate.py"), str(path)], capture_output=True, text=True)
    last = result.stdout.strip().splitlines()[-1] if result.stdout.strip() else "?"
    return "valid" if result.returncode == 0 else last.split(": ", 1)[-1]


def main() -> None:
    out, review = ROOT / "Localization/out", ROOT / "Localization/review"
    counts = {"translated": 0, "reviewed": 0}
    for code in PLAN:
        merged, reviewed, patch = out / f"{code}.json", out / f"{code}.reviewed.json", review / f"{code}.patch.json"
        if merged.exists():
            translation = validate(merged)
            counts["translated"] += translation == "valid"
        else:
            parts = parts_status(code)
            done = 5 - sum(1 for entry in parts["todo"] + parts["broken"] if not entry.startswith("meta"))
            translation = f"parts {max(done, 0)}/5" if parts["folder"].exists() else "-"
        state = "-"
        if patch.exists():
            try:
                data = json.loads(patch.read_text())
                changes = len(data.get("strings", {})) + len(data.get("demo", {})) + len(data.get("store", {}))
                if is_complete(data) and reviewed.exists():
                    state = f"done, {changes} changes, {validate(reviewed)}"
                    counts["reviewed"] += 1
                else:
                    state = f"in progress (through id {data.get('reviewedThrough', 0)}, {changes} changes)"
            except Exception as error:  # noqa: BLE001
                state = f"patch unreadable: {error}"
        elif reviewed.exists():
            state = f"done (full file), {validate(reviewed)}"
            counts["reviewed"] += 1
        print(f"{code:8} translation: {translation:24} review: {state}")
    print(f"\n{counts['translated']} of {len(PLAN)} translated and valid, {counts['reviewed']} reviewed.")


if __name__ == "__main__":
    main()
