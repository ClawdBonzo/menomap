#!/usr/bin/env python3
"""Assembles one language from its checkpointed parts and validates it.

    python3 Tools/loc_merge_parts.py it

Translators write small part files, so an interrupted session loses one part at most:

    Localization/out/parts/<code>/meta.json        {"language": "<code>", "register": "…", "glossary": {…}}
    Localization/out/parts/<code>/strings-1.json   {"<id>": "…" or {plural forms}}      ids   1–220
    Localization/out/parts/<code>/strings-2.json                                        ids 221–440
    Localization/out/parts/<code>/strings-3.json                                        ids 441–660
    Localization/out/parts/<code>/strings-4.json                                        ids 661–end
    Localization/out/parts/<code>/extras.json      {"demo": {…}, "store": {…}}

Run it after every part: it validates what exists so far and says what is still missing.
When every part is present it writes Localization/out/<code>.json and prints the validator's full report.
"""
import json, pathlib, subprocess, sys, tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
SOURCE = json.loads((ROOT / "Localization/source/strings_en.json").read_text())
SOURCE_IDS = {item["id"] for item in SOURCE["strings"]}   # ids are permanent; retired ones leave gaps
PART_SIZE = 220


def part_ranges() -> list:
    last = max(item["id"] for item in SOURCE["strings"])
    starts = list(range(1, last + 1, PART_SIZE))[:4]
    return [(start, last if index == len(starts) - 1 else start + PART_SIZE - 1) for index, start in enumerate(starts)]


def load(path: pathlib.Path):
    try:
        return json.loads(path.read_text()), None
    except FileNotFoundError:
        return None, "missing"
    except Exception as error:  # noqa: BLE001
        return None, f"INVALID JSON: {error}"


def status(code: str) -> dict:
    """What exists for a language: used by this tool and by loc_status.py."""
    folder = ROOT / "Localization/out/parts" / code
    report = {"folder": folder, "strings": {}, "todo": [], "broken": []}
    meta, error = load(folder / "meta.json")
    if error:
        (report["broken"] if error != "missing" else report["todo"]).append(f"meta.json ({error})")
    report["meta"] = meta or {}
    for number, (first, last) in enumerate(part_ranges(), start=1):
        name = f"strings-{number}.json"
        part, error = load(folder / name)
        if error:
            (report["broken"] if error != "missing" else report["todo"]).append(f"{name} ids {first}–{last} ({error})")
            continue
        report["strings"].update({str(key): value for key, value in part.items()})
        absent = [i for i in range(first, last + 1) if i in SOURCE_IDS and str(i) not in part]
        if absent:
            report["todo"].append(f"{name}: ids still missing {absent[:12]}{'…' if len(absent) > 12 else ''}")
            if len(absent) <= 5:   # usually a string added to the app after this part was written
                for item in SOURCE["strings"]:
                    if item["id"] in absent:
                        report["todo"].append(f"    [{item['id']}] {item['en']!r} :: {item.get('note', '')}")
    extras, error = load(folder / "extras.json")
    if error:
        (report["broken"] if error != "missing" else report["todo"]).append(f"extras.json: demo + store ({error})")
    report["extras"] = extras or {}
    return report


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    code = sys.argv[1]
    report = status(code)
    merged = {
        "language": code,
        "register": report["meta"].get("register", ""),
        "glossary": report["meta"].get("glossary", {}),
        "strings": dict(sorted(report["strings"].items(), key=lambda pair: int(pair[0]) if pair[0].isdigit() else 0)),
        "demo": report["extras"].get("demo", {}),
        "store": report["extras"].get("store", {}),
    }
    complete = not report["todo"] and not report["broken"]
    target = ROOT / "Localization/out" / f"{code}.json"
    if complete:
        target.write_text(json.dumps(merged, ensure_ascii=False, indent=1) + "\n")
        checked = target
    else:
        checked = pathlib.Path(tempfile.mkdtemp()) / f"{code}.json"
        checked.write_text(json.dumps(merged, ensure_ascii=False))

    result = subprocess.run([sys.executable, str(ROOT / "Tools/loc_validate.py"), str(checked)], capture_output=True, text=True)
    lines = result.stdout.strip().splitlines()
    if not complete:
        # Only report on what has been written so far.
        have_extras, have_meta = bool(report["extras"]), bool(report["meta"])
        lines = [line for line in lines[:-1]
                 if "] missing ::" not in line
                 and (have_extras or not (line.startswith("FAIL [store") or line.startswith("FAIL [demo")))
                 and (have_meta or "glossary missing" not in line)]
    print("\n".join(lines))
    for entry in report["broken"]:
        print("BROKEN", entry)
    for entry in report["todo"]:
        print("TODO  ", entry)
    if complete:
        print(f"All parts present -> {target.relative_to(ROOT)}")
        return result.returncode
    problems = sum(1 for line in lines if line.startswith("FAIL")) + len(report["broken"])
    print(f"{code}: {len(report['strings'])} strings so far, {problems} problems in what exists, {len(report['todo'])} parts to do")
    return 1


if __name__ == "__main__":
    sys.exit(main())
