#!/usr/bin/env python3
"""Writes the safety auditor's blind input: only the translated SAFETY strings, no English.

    python3 Tools/loc_safety_blind.py de   ->  Localization/review/de.safety_blind.json
The auditor back-translates these BEFORE opening the English source.
"""
import json, pathlib, sys
ROOT = pathlib.Path(__file__).resolve().parent.parent
code = sys.argv[1]
source = json.loads((ROOT / "Localization/source/strings_en.json").read_text())
path = ROOT / "Localization/out" / f"{code}.reviewed.json"
if not path.exists():
    path = ROOT / "Localization/out" / f"{code}.json"
data = json.loads(path.read_text())
blind = {str(i["id"]): data["strings"].get(str(i["id"])) for i in source["strings"] if i.get("safety")}
desc = data.get("store", {}).get("description", "")
blind["store.description.disclaimer"] = [p for p in desc.split("\n\n") if "MenoMap" in p][-1:] if desc else []
out = ROOT / "Localization/review" / f"{code}.safety_blind.json"
out.write_text(json.dumps(blind, ensure_ascii=False, indent=1))
print(f"{len(blind)} safety entries -> {out.relative_to(ROOT)}")
