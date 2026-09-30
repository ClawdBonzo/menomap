#!/usr/bin/env python3
"""MenoMap App Store Connect setup (idempotent). Run a stage:

    python3 Tools/asc_setup.py products     # group, subscriptions, localizations, availability
    python3 Tools/asc_setup.py prices       # USD base + per-territory bands (Docs/MARKETS.md) for subscriptions
    python3 Tools/asc_setup.py trial        # 7-day free trial on yearly, every territory
    python3 Tools/asc_setup.py iaps         # lifetime (non-consumable) + Visit Report (consumable)
    Offer configurations (friend + clinic) already exist; these run AFTER the first approval:
    python3 Tools/asc_setup.py codes        # MENOFRIEND custom code
    python3 Tools/asc_setup.py clinic SMITH30   # one clinic's custom code (500 redemptions)
    python3 Tools/asc_setup.py winback      # 50% off the first year back for lapsed subscribers

Storefronts: every territory except Russia and China mainland (Rob, 2026-09-29).
"""
import json, sys, time
from asc_api import call

BUNDLE = "app.gwlabs.menomap"
GROUP_NAME = "MenoMap Pro"
EXCLUDED = {"RUS", "CHN"}
REVIEW_NOTE = ("MenoMap Pro unlocks 30/90/365-day stats, patterns in the user's own entries, two-week experiments, the full "
               "monthly Heat Report, the clinician PDF and medication reminders. The paywall opens from Visit > Create my "
               "notes, from a locked pattern in the Week tab, or from You > MenoMap Pro. All data stays on device.")
SUBSCRIPTIONS = [  # productId, reference name, period, USD, groupLevel, familySharable, display name, description
    ("menomap.pro.yearly", "MenoMap Pro Yearly", "ONE_YEAR", "49.99", 1, True,
     "MenoMap Pro Yearly", "Patterns, stats, experiments and clinician notes."),
    ("menomap.pro.monthly", "MenoMap Pro Monthly", "ONE_MONTH", "9.99", 2, False,
     "MenoMap Pro Monthly", "Patterns, stats, experiments and clinician notes."),
]
IAPS = [  # productId, reference name, type, USD, familySharable, display name, description
    ("menomap.pro.lifetime", "MenoMap Pro Lifetime", "NON_CONSUMABLE", "99.99", True,
     "MenoMap Pro Lifetime", "Every Pro feature, forever. One payment."),
    ("menomap.visitreport.single", "Visit Report (single)", "CONSUMABLE", "4.99", False,
     "Visit Report", "One full clinician PDF covering up to 90 days."),
]
# Docs/MARKETS.md price bands (share of Apple's equalized US price). Everything else: 100%.
BANDS = {
    0.75: ["ESP", "ITA", "PRT", "KOR", "TWN", "HKG", "CZE", "POL", "GRC", "HRV", "SVK", "HUN"],
    0.50: ["BRA", "MEX", "ARG", "CHL", "COL", "PER", "ECU", "URY", "PRY", "BOL", "CRI", "PAN", "GTM", "DOM", "SLV",
           "HND", "NIC", "VEN", "TUR", "ROU", "UKR", "ZAF", "MYS", "THA"],
    0.35: ["IND", "IDN", "VNM", "PHL", "EGY", "PAK", "NGA", "KEN", "BGD", "LKA", "NPL", "GHA", "TZA", "UGA", "MAR",
           "TUN", "KAZ", "UZB", "MNG", "KHM", "LAO", "MMR", "ZWE", "ZMB", "CMR", "SEN", "CIV"],
}
BAND_OF = {t: f for f, ts in BANDS.items() for t in ts}


def req(method, path, body=None, what=""):
    for attempt in range(8):
        try:
            status, data = call(method, path, body)
        except OSError as e:  # timeouts / connection resets: back off and retry
            status, data = 599, {"error": str(e)}
            time.sleep(5 * (attempt + 1))
            continue
        if status != 429:
            break
        time.sleep(4 * (attempt + 1))
    if status >= 300 and what:
        print(f"  ! {what}: {status} {json.dumps(data)[:500]}")
    return status, data


def pages(path):
    items = []
    while path:
        status, data = req("GET", path)
        if status >= 300:
            print("  ! GET", path, status, json.dumps(data)[:300]); break
        items += data.get("data", [])
        path = data.get("links", {}).get("next", "").replace("https://api.appstoreconnect.apple.com", "") or None
    return items


def app_id():
    data = req("GET", f"/v1/apps?filter[bundleId]={BUNDLE}")[1]["data"]
    return data[0]["id"]


def territories():
    return sorted(t["id"] for t in pages("/v1/territories?limit=200") if t["id"] not in EXCLUDED)


def group_id(app):
    for g in req("GET", f"/v1/apps/{app}/subscriptionGroups")[1].get("data", []):
        if g["attributes"]["referenceName"] == GROUP_NAME:
            return g["id"]
    s, d = req("POST", "/v1/subscriptionGroups", {"data": {"type": "subscriptionGroups", "attributes": {"referenceName": GROUP_NAME},
               "relationships": {"app": {"data": {"type": "apps", "id": app}}}}}, "create group")
    gid = d["data"]["id"]
    req("POST", "/v1/subscriptionGroupLocalizations", {"data": {"type": "subscriptionGroupLocalizations",
        "attributes": {"name": GROUP_NAME, "locale": "en-US"},
        "relationships": {"subscriptionGroup": {"data": {"type": "subscriptionGroups", "id": gid}}}}}, "group localization")
    return gid


def subs(gid):
    return {s["attributes"]["productId"]: s["id"] for s in pages(f"/v1/subscriptionGroups/{gid}/subscriptions?limit=50")}


def stage_products(app, terrs):
    gid = group_id(app)
    print("group", gid)
    have = subs(gid)
    for pid, ref, period, usd, level, family, name, desc in SUBSCRIPTIONS:
        sid = have.get(pid)
        if not sid:
            s, d = req("POST", "/v1/subscriptions", {"data": {"type": "subscriptions", "attributes": {
                "name": ref, "productId": pid, "subscriptionPeriod": period, "familySharable": family,
                "reviewNote": REVIEW_NOTE, "groupLevel": level},
                "relationships": {"group": {"data": {"type": "subscriptionGroups", "id": gid}}}}}, f"create {pid}")
            sid = d["data"]["id"]
            req("POST", "/v1/subscriptionLocalizations", {"data": {"type": "subscriptionLocalizations",
                "attributes": {"name": name, "description": desc, "locale": "en-US"},
                "relationships": {"subscription": {"data": {"type": "subscriptions", "id": sid}}}}}, f"{pid} localization")
        s, d = req("GET", f"/v1/subscriptions/{sid}/subscriptionAvailability")
        if not (s == 200 and d.get("data")):
            req("POST", "/v1/subscriptionAvailabilities", {"data": {"type": "subscriptionAvailabilities",
                "attributes": {"availableInNewTerritories": True},
                "relationships": {"subscription": {"data": {"type": "subscriptions", "id": sid}},
                                  "availableTerritories": {"data": [{"type": "territories", "id": t} for t in terrs]}}}}, f"{pid} availability")
        print(pid, sid)


def nearest_point(points, target):
    return min(points, key=lambda p: abs(float(p["attributes"]["customerPrice"]) - target))


def stage_prices(app, terrs):
    gid = group_id(app)
    for pid, _, _, usd, *_ in SUBSCRIPTIONS:
        sid = subs(gid)[pid]
        prices = pages(f"/v1/subscriptions/{sid}/prices?limit=200&include=territory")
        have = {p["relationships"]["territory"]["data"]["id"] for p in prices}
        if "USA" not in have:
            usa = pages(f"/v1/subscriptions/{sid}/pricePoints?filter[territory]=USA&limit=200")
            point = next(p for p in usa if p["attributes"]["customerPrice"] == usd)
            req("POST", "/v1/subscriptionPrices", {"data": {"type": "subscriptionPrices", "attributes": {"preserveCurrentPrice": False},
                "relationships": {"subscription": {"data": {"type": "subscriptions", "id": sid}},
                                  "subscriptionPricePoint": {"data": {"type": "subscriptionPricePoints", "id": point["id"]}}}}}, f"{pid} USA")
            have.add("USA")
            base = point["id"]
        else:
            base = next(p for p in pages(f"/v1/subscriptions/{sid}/prices?limit=200&include=subscriptionPricePoint,territory")
                        if p["relationships"]["territory"]["data"]["id"] == "USA")["relationships"]["subscriptionPricePoint"]["data"]["id"]
        equal = {p["relationships"]["territory"]["data"]["id"]: p for p in pages(f"/v1/subscriptionPricePoints/{base}/equalizations?limit=200&include=territory")}
        made = failed = 0
        for t in terrs:
            if t in have or t not in equal:
                continue
            point = equal[t]
            factor = BAND_OF.get(t)
            if factor:
                local = pages(f"/v1/subscriptions/{sid}/pricePoints?filter[territory]={t}&limit=200")
                if local:
                    point = nearest_point(local, float(point["attributes"]["customerPrice"]) * factor)
            s, d = req("POST", "/v1/subscriptionPrices", {"data": {"type": "subscriptionPrices", "attributes": {"preserveCurrentPrice": False},
                "relationships": {"subscription": {"data": {"type": "subscriptions", "id": sid}},
                                  "subscriptionPricePoint": {"data": {"type": "subscriptionPricePoints", "id": point["id"]}}}}},
                f"{pid} {t}" if failed < 3 else "")
            made += s < 300
            failed += s >= 300
        print(pid, "territories priced before", len(have), "created", made, "failed", failed)


def stage_trial(app, terrs):
    sid = subs(group_id(app))["menomap.pro.yearly"]
    have = {o["relationships"]["territory"]["data"]["id"] for o in pages(f"/v1/subscriptions/{sid}/introductoryOffers?limit=200")
            if o.get("relationships", {}).get("territory", {}).get("data")}
    made = failed = 0
    for t in terrs:
        if t in have:
            continue
        s, d = req("POST", "/v1/subscriptionIntroductoryOffers", {"data": {"type": "subscriptionIntroductoryOffers",
            "attributes": {"duration": "ONE_WEEK", "offerMode": "FREE_TRIAL", "numberOfPeriods": 1},
            "relationships": {"subscription": {"data": {"type": "subscriptions", "id": sid}},
                              "territory": {"data": {"type": "territories", "id": t}}}}}, f"trial {t}" if failed < 3 else "")
        made += s < 300
        failed += s >= 300
    print("yearly trial: had", len(have), "created", made, "failed", failed)


def stage_iaps(app, terrs):
    existing = {i["attributes"]["productId"]: i["id"] for i in pages(f"/v1/apps/{app}/inAppPurchasesV2?limit=200")}
    for pid, ref, kind, usd, family, name, desc in IAPS:
        iid = existing.get(pid)
        if not iid:
            s, d = req("POST", "/v2/inAppPurchases", {"data": {"type": "inAppPurchases", "attributes": {
                "name": ref, "productId": pid, "inAppPurchaseType": kind, "reviewNote": REVIEW_NOTE, "familySharable": family},
                "relationships": {"app": {"data": {"type": "apps", "id": app}}}}}, f"create {pid}")
            iid = d["data"]["id"]
        s, d = req("GET", f"/v2/inAppPurchases/{iid}/inAppPurchaseLocalizations")
        if not d.get("data"):
            req("POST", "/v1/inAppPurchaseLocalizations", {"data": {"type": "inAppPurchaseLocalizations",
                "attributes": {"name": name, "description": desc, "locale": "en-US"},
                "relationships": {"inAppPurchaseV2": {"data": {"type": "inAppPurchases", "id": iid}}}}}, f"{pid} localization")
        s, d = req("GET", f"/v2/inAppPurchases/{iid}/iapPriceSchedule")
        if not (s == 200 and d.get("data")):
            usa = pages(f"/v2/inAppPurchases/{iid}/pricePoints?filter[territory]=USA&limit=200")
            base = next(p for p in usa if p["attributes"]["customerPrice"] == usd)
            equal = {p["relationships"]["territory"]["data"]["id"]: p for p in
                     pages(f"/v1/inAppPurchasePricePoints/{base['id']}/equalizations?limit=200&include=territory")}
            manual = [("USA", base["id"])]
            for t, factor in BAND_OF.items():
                if t in terrs and t in equal:
                    local = pages(f"/v2/inAppPurchases/{iid}/pricePoints?filter[territory]={t}&limit=200")
                    if local:
                        manual.append((t, nearest_point(local, float(equal[t]["attributes"]["customerPrice"]) * factor)["id"]))
            s, d = req("POST", "/v1/inAppPurchasePriceSchedules", {"data": {"type": "inAppPurchasePriceSchedules",
                "relationships": {"inAppPurchase": {"data": {"type": "inAppPurchases", "id": iid}},
                                  "baseTerritory": {"data": {"type": "territories", "id": "USA"}},
                                  "manualPrices": {"data": [{"type": "inAppPurchasePrices", "id": f"${{p{i}}}"} for i in range(len(manual))]}}},
                "included": [{"type": "inAppPurchasePrices", "id": f"${{p{i}}}", "attributes": {"startDate": None},
                              "relationships": {"inAppPurchasePricePoint": {"data": {"type": "inAppPurchasePricePoints", "id": pt}}}}
                             for i, (t, pt) in enumerate(manual)]}, f"{pid} prices")
            print(pid, "price schedule", s, "manual territories", len(manual))
        s, d = req("GET", f"/v2/inAppPurchases/{iid}/inAppPurchaseAvailability")
        if not (s == 200 and d.get("data")):
            req("POST", "/v1/inAppPurchaseAvailabilities", {"data": {"type": "inAppPurchaseAvailabilities",
                "attributes": {"availableInNewTerritories": True},
                "relationships": {"inAppPurchase": {"data": {"type": "inAppPurchases", "id": iid}},
                                  "availableTerritories": {"data": [{"type": "territories", "id": t} for t in terrs]}}}}, f"{pid} availability")
        print(pid, iid)


# Offer configurations created 2026-09-29 (codes can only be issued once the app is live and the subscription approved).
FRIEND_OFFER = "f3e0843c-cd6e-425f-b527-ddb82ad04eb0"   # "Friend pass - 1 month free", yearly, new subscribers
CLINIC_OFFER = "4d96660a-1059-4ebe-81cf-f7d39c92b4ab"   # "Clinic referral - 1 month free", yearly, new subscribers


def add_custom_code(offer, code, count=500):
    s, d = req("POST", "/v1/subscriptionOfferCodeCustomCodes", {"data": {"type": "subscriptionOfferCodeCustomCodes",
        "attributes": {"customCode": code, "numberOfCodes": count, "expirationDate": "2027-12-31"},
        "relationships": {"offerCode": {"data": {"type": "subscriptionOfferCodes", "id": offer}}}}}, code)
    print(code, "created" if s < 300 else f"failed ({s})")


def stage_codes(app, terrs):
    """After approval: the friend code (10,000 redemptions)."""
    add_custom_code(FRIEND_OFFER, "MENOFRIEND", 10000)


def stage_winback(app, terrs):
    """After approval: 50% off the first year back, every territory, for users lapsed 1-24 months."""
    import datetime
    sid = subs(group_id(app))["menomap.pro.yearly"]
    current = {}
    for p in pages(f"/v1/subscriptions/{sid}/prices?limit=200&include=subscriptionPricePoint,territory"):
        current[p["relationships"]["territory"]["data"]["id"]] = p["relationships"]["subscriptionPricePoint"]["data"]["id"]
    points = {}
    for i, t in enumerate(terrs):
        if t not in current:
            continue
        local = pages(f"/v1/subscriptions/{sid}/pricePoints?filter[territory]={t}&limit=200")
        mine = next((p for p in local if p["id"] == current[t]), None)
        if mine:
            points[t] = nearest_point(local, float(mine["attributes"]["customerPrice"]) / 2)["id"]
    start = (datetime.date.today() + datetime.timedelta(days=2)).isoformat()
    items = list(points.items())
    s, d = req("POST", "/v1/winBackOffers", {"data": {"type": "winBackOffers", "attributes": {
        "referenceName": "Win-back: 50% off first year", "offerId": "menomap_winback_50", "duration": "ONE_YEAR",
        "offerMode": "PAY_UP_FRONT", "periodCount": 1, "customerEligibilityPaidSubscriptionDurationInMonths": 1,
        "customerEligibilityTimeSinceLastSubscribedInMonths": {"minimum": 1, "maximum": 24},
        "customerEligibilityWaitBetweenOffersInMonths": 6, "startDate": start, "priority": "HIGH",
        "promotionIntent": "USE_AUTO_GENERATED_ASSETS"},
        "relationships": {"subscription": {"data": {"type": "subscriptions", "id": sid}},
                          "prices": {"data": [{"type": "winBackOfferPrices", "id": f"${{p{i}}}"} for i in range(len(items))]}}},
        "included": [{"type": "winBackOfferPrices", "id": f"${{p{i}}}", "relationships": {
            "territory": {"data": {"type": "territories", "id": t}},
            "subscriptionPricePoint": {"data": {"type": "subscriptionPricePoints", "id": pt}}}} for i, (t, pt) in enumerate(items)]},
        "winback")
    print("win-back", s, "territories", len(items), "starts", start)


def iap_locales():
    """AppStore/metadata/<ASC locale>/iap.json, written by Tools/asc_listing.py from the reviewed translations."""
    import pathlib
    root = pathlib.Path(__file__).resolve().parent.parent / "AppStore/metadata"
    return {p.parent.name: json.loads(p.read_text()) for p in sorted(root.glob("*/iap.json"))}


def stage_localize(app, terrs):
    """Group, subscription and IAP names/descriptions in every listing locale (skips locales that already exist)."""
    locs = iap_locales()
    gid = group_id(app)
    have = {l["attributes"]["locale"] for l in pages(f"/v1/subscriptionGroups/{gid}/subscriptionGroupLocalizations?limit=200")}
    for loc, iap in locs.items():
        if loc not in have:
            req("POST", "/v1/subscriptionGroupLocalizations", {"data": {"type": "subscriptionGroupLocalizations",
                "attributes": {"name": iap.get("groupName", GROUP_NAME), "locale": loc},
                "relationships": {"subscriptionGroup": {"data": {"type": "subscriptionGroups", "id": gid}}}}}, f"group {loc}")
    plans = {"menomap.pro.yearly": "yearly", "menomap.pro.monthly": "monthly"}
    for pid, sid in subs(gid).items():
        have = {l["attributes"]["locale"] for l in pages(f"/v1/subscriptions/{sid}/subscriptionLocalizations?limit=200")}
        for loc, iap in locs.items():
            if loc in have or plans.get(pid) not in iap:
                continue
            p = iap[plans[pid]]
            req("POST", "/v1/subscriptionLocalizations", {"data": {"type": "subscriptionLocalizations",
                "attributes": {"name": p["name"], "description": p["description"], "locale": loc},
                "relationships": {"subscription": {"data": {"type": "subscriptions", "id": sid}}}}}, f"{pid} {loc}")
    keys = {"menomap.pro.lifetime": "lifetime", "menomap.visitreport.single": "visitReport"}
    for item in pages(f"/v1/apps/{app}/inAppPurchasesV2?limit=200"):
        pid, iid = item["attributes"]["productId"], item["id"]
        have = {l["attributes"]["locale"] for l in pages(f"/v2/inAppPurchases/{iid}/inAppPurchaseLocalizations?limit=200")}
        for loc, iap in locs.items():
            if loc in have or keys.get(pid) not in iap:
                continue
            p = iap[keys[pid]]
            req("POST", "/v1/inAppPurchaseLocalizations", {"data": {"type": "inAppPurchaseLocalizations",
                "attributes": {"name": p["name"], "description": p["description"], "locale": loc},
                "relationships": {"inAppPurchaseV2": {"data": {"type": "inAppPurchases", "id": iid}}}}}, f"{pid} {loc}")
    print("localized", len(locs), "locales")


def upload_review_shot(kind, rel, owner_id, path):
    """Reserve, upload and commit an App Review screenshot (subscription or in-app purchase)."""
    import hashlib, os, urllib.request
    data = open(path, "rb").read()
    s, d = req("POST", f"/v1/{kind}", {"data": {"type": kind, "attributes": {"fileName": os.path.basename(path), "fileSize": len(data)},
               "relationships": {rel: {"data": {"type": rel + "s" if rel == "subscription" else "inAppPurchases", "id": owner_id}}}}}, f"reserve {kind}")
    if s >= 300:
        return
    shot = d["data"]
    for op in shot["attributes"]["uploadOperations"]:
        chunk = data[op["offset"]:op["offset"] + op["length"]]
        r = urllib.request.Request(op["url"], data=chunk, method=op["method"], headers={h["name"]: h["value"] for h in op["requestHeaders"]})
        urllib.request.urlopen(r, timeout=120).read()
    req("PATCH", f"/v1/{kind}/{shot['id']}", {"data": {"type": kind, "id": shot["id"], "attributes": {
        "uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}}, f"commit {kind}")


def stage_reviewshots(app, terrs, path):
    """The paywall screenshot App Review requires on every subscription and in-app purchase (skips ones that have it)."""
    gid = group_id(app)
    for pid, sid in subs(gid).items():
        s, d = req("GET", f"/v1/subscriptions/{sid}/appStoreReviewScreenshot")
        if not d.get("data"):
            upload_review_shot("subscriptionAppStoreReviewScreenshots", "subscription", sid, path)
            print("review screenshot", pid)
    for item in pages(f"/v1/apps/{app}/inAppPurchasesV2?limit=200"):
        s, d = req("GET", f"/v2/inAppPurchases/{item['id']}/appStoreReviewScreenshot")
        if not d.get("data"):
            upload_review_shot("inAppPurchaseAppStoreReviewScreenshots", "inAppPurchaseV2", item["id"], path)
            print("review screenshot", item["attributes"]["productId"])


if __name__ == "__main__":
    stage = sys.argv[1]
    if stage == "reviewshots":
        a = app_id()
        stage_reviewshots(a, [], sys.argv[2])
        sys.exit()
    if stage == "clinic":
        add_custom_code(CLINIC_OFFER, sys.argv[2].upper())
        sys.exit()
    app = app_id()
    terrs = territories()
    print("app", app, "territories", len(terrs))
    {"products": stage_products, "prices": stage_prices, "trial": stage_trial, "iaps": stage_iaps, "codes": stage_codes, "winback": stage_winback,
     "localize": stage_localize}[stage](app, terrs)
