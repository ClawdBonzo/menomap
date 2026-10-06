#!/usr/bin/env python3
"""Makes sure every app on the account sends each new TestFlight build to Rob as soon as it's processed.

    python3 Tools/testflight_autosend.py

For each app: finds an internal TestFlight group with "automatic distribution" (hasAccessToAllBuilds) that has
Rob in it. If there isn't one, it uses an existing auto-distribution internal group or creates one named "Rob",
then adds Rob. Safe to run any time; it changes nothing that's already right. Tools/upload_build.sh runs it.
"""
import sys
from asc_api import call

EMAIL = "rgoldstein45@gmail.com"


def members(group_id: str) -> set[str]:
    _, m = call("GET", f"/v1/betaGroups/{group_id}/betaTesters?limit=200&fields[betaTesters]=email")
    return {(t["attributes"].get("email") or "").lower() for t in m.get("data", [])}


def ensure(app: dict) -> str:
    _, g = call("GET", f"/v1/apps/{app['id']}/betaGroups?fields[betaGroups]=name,isInternalGroup,hasAccessToAllBuilds")
    auto = [x for x in g.get("data", []) if x["attributes"]["isInternalGroup"] and x["attributes"].get("hasAccessToAllBuilds")]
    for x in auto:
        if EMAIL in members(x["id"]):
            return f"ok ({x['attributes']['name']})"
    if auto:
        group = auto[0]
    else:
        status, r = call("POST", "/v1/betaGroups", {"data": {"type": "betaGroups",
            "attributes": {"name": "Rob", "isInternalGroup": True, "hasAccessToAllBuilds": True},
            "relationships": {"app": {"data": {"type": "apps", "id": app["id"]}}}}})
        if status != 201:
            return f"FAILED creating group: {r.get('errors', r)}"
        group = r["data"]
    status, r = call("POST", "/v1/betaTesters", {"data": {"type": "betaTesters",
        "attributes": {"email": EMAIL, "firstName": "Rob", "lastName": "Goldstein"},
        "relationships": {"betaGroups": {"data": [{"type": "betaGroups", "id": group["id"]}]}}}})
    if status not in (200, 201, 409) and EMAIL not in members(group["id"]):
        return f"FAILED adding tester: {r.get('errors', r)}"
    return f"added to {group['attributes']['name']}"


def main():
    _, r = call("GET", "/v1/apps?limit=200&fields[apps]=name")
    failed = False
    for app in r["data"]:
        result = ensure(app)
        failed |= result.startswith("FAILED")
        print(f"{app['attributes']['name'][:40]:40} {result}")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
