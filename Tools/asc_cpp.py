#!/usr/bin/env python3
"""Custom Product Pages for ads and outreach links (idempotent: skips pages that already exist).

    python3 Tools/asc_cpp.py

Each page reuses the store screenshots in AppStore/screenshots/<locale>/ (positions 01-09, see asc_listing.ORDER)
in a different order, with its own promotional text. English storefronts only for now.
"""
import hashlib, os, urllib.request
from asc_api import call

APP = "6817484445"
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LOCALES = ["en-US", "en-GB", "en-AU", "en-CA"]
SHOT_TYPE = "APP_IPHONE_67"

# Store positions: 01 Today, 02 Night Watch, 03 clinician notes PDF, 04 Week heat map, 05 patterns,
# 06 Apple Health, 07 Apple Watch, 08 experiments, 09 privacy.
PAGES = [
    {"name": "Doctor visit notes",
     "order": ["03", "01", "04", "05", "02", "07", "08", "09", "06"],
     "promo": "Walk into your appointment with one clear page: how often, how intense, what's changed. "
              "Log in one tap. Your data stays on your iPhone."},
    {"name": "Night sweats",
     "order": ["02", "07", "01", "04", "03", "05", "08", "09", "06"],
     "promo": "Night sweat at 3am? One tap from your Lock Screen or Apple Watch, no unlocking. "
              "See your nights as a heat map and bring notes to your doctor."},
]


def ok(status, body, what):
    if status >= 300:
        raise SystemExit(f"{what} failed ({status}): {body.get('errors', body)}")
    return body


def upload(set_id, path):
    data = open(path, "rb").read()
    s, d = call("POST", "/v1/appScreenshots", {"data": {"type": "appScreenshots",
        "attributes": {"fileName": os.path.basename(path), "fileSize": len(data)},
        "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": set_id}}}}})
    shot = ok(s, d, "reserve")["data"]
    for op in shot["attributes"]["uploadOperations"]:
        chunk = data[op["offset"]:op["offset"] + op["length"]]
        r = urllib.request.Request(op["url"], data=chunk, method=op["method"],
                                   headers={h["name"]: h["value"] for h in op["requestHeaders"]})
        urllib.request.urlopen(r, timeout=120).read()
    s, d = call("PATCH", f"/v1/appScreenshots/{shot['id']}", {"data": {"type": "appScreenshots", "id": shot["id"],
        "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}})
    ok(s, d, "commit")


def main():
    _, existing = call("GET", f"/v1/apps/{APP}/appCustomProductPages?limit=50")
    have = {p["attributes"]["name"] for p in existing.get("data", [])}
    for page in PAGES:
        if page["name"] in have:
            print(page["name"], "exists")
            continue
        assert len(page["promo"]) <= 170, page["name"]
        s, d = call("POST", "/v1/appCustomProductPages", {"data": {"type": "appCustomProductPages",
            "attributes": {"name": page["name"]},
            "relationships": {"app": {"data": {"type": "apps", "id": APP}},
                              "appCustomProductPageVersions": {"data": [{"type": "appCustomProductPageVersions", "id": "${v}"}]}}},
            "included": [{"type": "appCustomProductPageVersions", "id": "${v}", "relationships": {
                "appCustomProductPageLocalizations": {"data": [{"type": "appCustomProductPageLocalizations", "id": f"${{l{i}}}"}
                                                               for i in range(len(LOCALES))]}}}]
                        + [{"type": "appCustomProductPageLocalizations", "id": f"${{l{i}}}",
                            "attributes": {"locale": loc, "promotionalText": page["promo"]}} for i, loc in enumerate(LOCALES)]})
        cpp = ok(s, d, page["name"])["data"]
        _, v = call("GET", f"/v1/appCustomProductPages/{cpp['id']}/appCustomProductPageVersions")
        version = v["data"][0]["id"]
        _, locs = call("GET", f"/v1/appCustomProductPageVersions/{version}/appCustomProductPageLocalizations?limit=50")
        for loc in locs["data"]:
            locale = loc["attributes"]["locale"]
            s, d = call("POST", "/v1/appScreenshotSets", {"data": {"type": "appScreenshotSets",
                "attributes": {"screenshotDisplayType": SHOT_TYPE},
                "relationships": {"appCustomProductPageLocalization": {"data": {"type": "appCustomProductPageLocalizations", "id": loc["id"]}}}}})
            set_id = ok(s, d, f"set {locale}")["data"]["id"]
            for pos in page["order"]:
                upload(set_id, os.path.join(ROOT, "AppStore/screenshots", locale, f"{pos}.png"))
            print(page["name"], locale, "uploaded", len(page["order"]))
        print(page["name"], "created", cpp["id"])


if __name__ == "__main__":
    main()
