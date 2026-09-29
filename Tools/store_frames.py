#!/usr/bin/env python3
"""Prints frames.json for the compositor: headlines per language (reviewed store data, English source for en)."""
import json, pathlib, sys
ROOT = pathlib.Path(__file__).resolve().parent.parent
src = json.loads((ROOT / "Localization/source/strings_en.json").read_text())["store"]["screenshots"]
out = {}
for code in sys.argv[1:]:
    if code == "en":
        heads = src
    else:
        p = ROOT / "Localization/out" / f"{code}.reviewed.json"
        heads = json.loads(p.read_text())["store"]["screenshots"] if p.exists() else src
    out[code] = {"headlines": heads, "rtl": code in ("ar", "he")}
print(json.dumps(out, ensure_ascii=False))
