#!/usr/bin/env python3
"""Tiny App Store Connect API client (JWT with the Fastlane key). Import or run:  python3 Tools/asc_api.py GET /v1/apps?limit=1"""
import json, os, sys, time, urllib.request, urllib.error
import jwt

KEY_ID = "K34HFNJTXH"
ISSUER_ID = "69a6de84-f289-47e3-e053-5b8c7c11a4d1"
KEY_PATH = os.path.expanduser("~/.private_keys/AuthKey_K34HFNJTXH.p8")
BASE = "https://api.appstoreconnect.apple.com"


def token() -> str:
    now = int(time.time())
    return jwt.encode({"iss": ISSUER_ID, "iat": now, "exp": now + 1200, "aud": "appstoreconnect-v1"},
                      open(KEY_PATH).read(), algorithm="ES256", headers={"kid": KEY_ID, "typ": "JWT"})


def call(method: str, path: str, body=None):
    request = urllib.request.Request(BASE + path, method=method, data=json.dumps(body).encode() if body is not None else None,
                                     headers={"Authorization": f"Bearer {token()}", "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(request) as response:
            text = response.read().decode()
            return response.status, (json.loads(text) if text else {})
    except urllib.error.HTTPError as error:
        text = error.read().decode()
        try:
            return error.code, json.loads(text)
        except ValueError:
            return error.code, {"raw": text}


if __name__ == "__main__":
    status, data = call(sys.argv[1], sys.argv[2], json.loads(sys.argv[3]) if len(sys.argv) > 3 else None)
    print(status)
    print(json.dumps(data, indent=1)[:3000])
