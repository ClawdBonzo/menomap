#!/usr/bin/env python3
"""Applies a reviewer's patch to a translation: writes the reviewed file and a readable change log, then validates.

    python3 Tools/loc_apply_review.py de

Input   Localization/out/<code>.json                 the translation under review (never modified)
        Localization/review/<code>.patch.json        only what the reviewer changes:
          {"verdict": "one paragraph on the translation's quality",
           "reviewedThrough": 478,                   last string id reviewed so far (checkpoint)
           "extrasReviewed": true,                   demo + store reviewed too
           "strings": {"46": {"to": "…", "why": "…"}, "17": {"to": {"one": "…", "other": "…"}, "why": "…"}},
           "demo":    {"d4": {"to": "…", "why": "…"}},
           "store":   {"subtitle": {"to": "…", "why": "…"}, "screenshots.3": {…}, "iap.weekly.name": {…}},
           "glossary": {"breadcrumb": "new rendering"},          optional
           "doubts":  ["anything that could not be settled, with the best guess and why"]}
Output  Localization/out/<code>.reviewed.json        what the catalog builder prefers
        Localization/review/<code>.md                verdict, table of changes, residual doubts
"""
import copy, json, pathlib, subprocess, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SOURCE = json.loads((ROOT / "Localization/source/strings_en.json").read_text())
LAST_ID = max(item["id"] for item in SOURCE["strings"])
# Ids above this joined the app after the first translation round. A language reviewed before that stays reviewed;
# the late strings reach it through loc_add_string.py.
FIRST_ROUND_LAST_ID = LAST_ID


def is_complete(patch: dict) -> bool:
    return int(patch.get("reviewedThrough", 0) or 0) >= min(LAST_ID, FIRST_ROUND_LAST_ID) and bool(patch.get("extrasReviewed"))


def cell(value) -> str:
    text = json.dumps(value, ensure_ascii=False) if isinstance(value, dict) else str(value)
    return text.replace("|", "\\|").replace("\n", " ⏎ ")


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    code = sys.argv[1]
    original_path = ROOT / "Localization/out" / f"{code}.json"
    patch_path = ROOT / "Localization/review" / f"{code}.patch.json"
    try:
        original = json.loads(original_path.read_text())
        patch = json.loads(patch_path.read_text())
    except Exception as error:  # noqa: BLE001
        print(f"cannot read input: {error}")
        return 1

    reviewed = copy.deepcopy(original)
    rows, problems = [], []

    def change(label, container, key, entry):
        if not isinstance(entry, dict) or "to" not in entry:
            problems.append(f"{label}: every change needs {{\"to\": …, \"why\": …}}")
            return
        if key not in container:
            problems.append(f"{label}: no such entry in the translation")
            return
        before = container[key]
        if before == entry["to"]:
            return
        container[key] = entry["to"]
        rows.append((label, before, entry["to"], entry.get("why", "")))

    for sid, entry in sorted(patch.get("strings", {}).items(), key=lambda pair: int(pair[0]) if pair[0].isdigit() else 0):
        change(sid, reviewed["strings"], sid, entry)
    for did, entry in patch.get("demo", {}).items():
        change(f"demo {did}", reviewed["demo"], did, entry)
    for path, entry in patch.get("store", {}).items():
        container, parts = reviewed["store"], path.split(".")
        for part in parts[:-1]:
            container = container.get(part, {}) if isinstance(container, dict) else {}
        change(f"store.{path}", container, parts[-1], entry)
    for term, rendering in patch.get("glossary", {}).items():
        reviewed.setdefault("glossary", {})[term] = rendering
    # Third pass: the safety auditor's fixes (Localization/review/<code>.audit.json), applied on top of the review.
    audit_path = ROOT / "Localization/review" / f"{code}.audit.json"
    if audit_path.exists():
        audit = json.loads(audit_path.read_text())
        for sid, entry in sorted(audit.get("fixes", {}).items(), key=lambda pair: int(pair[0]) if pair[0].isdigit() else 0):
            change(f"audit {sid}", reviewed["strings"], sid, entry)

    reviewed_path = original_path.with_name(f"{code}.reviewed.json")
    reviewed_path.write_text(json.dumps(reviewed, ensure_ascii=False, indent=1) + "\n")

    complete = is_complete(patch)
    total = len(original.get("strings", {})) + len(original.get("demo", {})) + 22
    log = [f"# {code}: review", "", patch.get("verdict", "(no verdict yet)"), "",
           f"Changed {len(rows)} of about {total} entries ({100 * len(rows) // max(total, 1)}%)."
           + ("" if complete else f" **Review incomplete**: strings reviewed through id {patch.get('reviewedThrough', 0)},"
                                  f" demo and store {'done' if patch.get('extrasReviewed') else 'not yet'}."), "",
           "| id | before | after | why |", "|---|---|---|---|"]
    log += [f"| {label} | {cell(before)} | {cell(after)} | {cell(why)} |" for label, before, after, why in rows]
    log += ["", "## Residual doubts", ""] + ([f"- {doubt}" for doubt in patch.get("doubts", [])] or ["None."])
    (ROOT / "Localization/review" / f"{code}.md").write_text("\n".join(log) + "\n")

    result = subprocess.run([sys.executable, str(ROOT / "Tools/loc_validate.py"), str(reviewed_path)], capture_output=True, text=True)
    print(result.stdout.strip())
    for line in problems:
        print("PATCH", line)
    print(f"{code}: {len(rows)} changes applied -> {reviewed_path.relative_to(ROOT)}"
          + ("" if complete else f"  (REVIEW INCOMPLETE: through id {patch.get('reviewedThrough', 0)}, extras {'done' if patch.get('extrasReviewed') else 'pending'})"))
    return 1 if (problems or result.returncode != 0) else 0


if __name__ == "__main__":
    sys.exit(main())
