#!/usr/bin/env python3
"""Builds the fastlane `deliver` folders for MenoMap's App Store listing from the reviewed translations.

    python3 Tools/asc_listing.py      then   fastlane metadata

AppStore/metadata/<ASC locale>/  name, subtitle, description, keywords, promotional text, URLs (34 languages plus
                                 en-AU, en-CA and fr-CA storefront copies)
AppStore/metadata/review_information/  App Review contact and notes
AppStore/screenshots/<ASC locale>/     the composed 6.9" frames from Tools/make_store_screenshots.sh
"""
import json, pathlib, shutil

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "Localization/out"
META = ROOT / "AppStore/metadata"
SHOTS = ROOT / "AppStore/screenshots"
COMPOSED = ROOT / "build/store/composed"

# Our language code → App Store Connect locale.
ASC = {"en": "en-US", "en-GB": "en-GB", "ar": "ar-SA", "cs": "cs", "da": "da", "de": "de-DE", "el": "el", "es": "es-ES",
       "es-419": "es-MX", "fi": "fi", "fr": "fr-FR", "he": "he", "hi": "hi", "hr": "hr", "hu": "hu", "id": "id", "it": "it",
       "ja": "ja", "ko": "ko", "ms": "ms", "nl": "nl-NL", "nb": "no", "pl": "pl", "pt-BR": "pt-BR", "pt-PT": "pt-PT",
       "ro": "ro", "sk": "sk", "sv": "sv", "th": "th", "tr": "tr", "uk": "uk", "vi": "vi", "zh-Hans": "zh-Hans",
       "zh-Hant": "zh-Hant"}
COPIES = {"en-AU": "en-GB", "en-CA": "en", "fr-CA": "fr"}  # extra storefront locales, same text as their source

# Store order of the composed frames (Tools/make_store_screenshots.sh numbers them 01-09). From 1.0.1 the clinician
# notes (05) move up to third: that's the frame someone comparing MenoMap with a GP-report app decides on.
ORDER = ["01", "02", "05", "03", "04", "06", "07", "08", "09"]

URLS = {"privacy_url": "https://gwlabs.app/menomap/privacy", "support_url": "https://gwlabs.app/support",
        "marketing_url": "https://gwlabs.app/menomap.html"}

REVIEW_NOTES = """Changes for Guideline 5.1.1(iv) (submission ce71d292): the Apple Health screen in onboarding no longer has a Skip or Back button, and its only button now reads "Continue" and always opens the Health permission request. The app continues whether the user allows or not.

MenoMap is a symptom tracker for perimenopause and menopause (hot flashes and night sweats). There is no account or sign-in, and all data stays on the device.

How to try it: complete the short onboarding (on the Apple Health screen, tap Continue; allowing or not allowing both continue), then tap "I'm having a surge" on the Today tab to start a timer, and tap again to end it and rate it. "Already over" logs one after the fact, and the "Evening check-in" card is on Today. To see two weeks of sample data without logging anything: Week tab > "See what two weeks looks like".

Apple Health: with permission, MenoMap reads hot flashes, night sweats, sleep, cycle data, other menopause symptoms, sleeping wrist temperature and (iOS 27) menopause stage, and writes the hot flashes, night sweats and bleeding the user logs. Health data is never sent off the device, never used for advertising, and never stored in iCloud by the app.

MenoMap Pro (subscription group "MenoMap Pro"; yearly has a 7-day free trial) and the one-time "Visit Report" are sold with StoreKit. The paywall opens from the Visit tab when creating the notes PDF, from any locked pattern on the Week tab, or from You > MenoMap Pro.

Other surfaces: Lock Screen/Control Center/Action Button controls and a Live Activity for a running surge; "Night Watch" (You > Night Watch) keeps a dim Lock Screen button overnight; an Apple Watch app; an iMessage sticker extension.

MenoMap is a wellness and education tool. It does not diagnose or recommend treatment, and the app says so in onboarding, in the Learn articles and on every PDF. Privacy policy: https://gwlabs.app/menomap/privacy"""


def write(folder: pathlib.Path, name: str, text: str):
    folder.mkdir(parents=True, exist_ok=True)
    (folder / f"{name}.txt").write_text(text.strip() + "\n")


def store_for(code: str) -> dict:
    if code == "en":
        return json.loads((ROOT / "Localization/source/strings_for_translation.json").read_text())["store"]
    return json.loads((OUT / f"{code}.reviewed.json").read_text())["store"]


def main():
    shutil.rmtree(META, ignore_errors=True)
    shutil.rmtree(SHOTS, ignore_errors=True)
    for code, asc in list(ASC.items()) + [(src, asc) for asc, src in COPIES.items()]:
        s = store_for(code)
        folder = META / asc
        for key, field in [("name", "name"), ("subtitle", "subtitle"), ("description", "description"),
                           ("keywords", "keywords"), ("promotional_text", "promotionalText")]:
            write(folder, key, s[field])
        for key, url in URLS.items():
            write(folder, key, url)
        (folder / "iap.json").write_text(json.dumps(s["iap"], ensure_ascii=False, indent=1) + "\n")
        shots = COMPOSED / code
        dest = SHOTS / asc
        dest.mkdir(parents=True, exist_ok=True)
        for position, frame in enumerate(ORDER, start=1):
            shutil.copy(shots / f"{frame}.png", dest / f"{position:02d}.png")
        assert len(list(dest.glob("*.png"))) == 9, f"{asc}: expected 9 screenshots"
        assert len(s["name"]) <= 30 and len(s["subtitle"]) <= 30 and len(s["keywords"]) <= 100, f"{asc}: length"
        assert len(s["promotionalText"]) <= 170 and len(s["description"]) <= 4000, f"{asc}: length"
    write(META, "copyright", "2026 GW Labs")
    write(META, "primary_category", "HEALTH_AND_FITNESS")
    write(META, "secondary_category", "MEDICAL")
    review = META / "review_information"
    for key, value in [("first_name", "Rob"), ("last_name", "Goldstein"), ("phone_number", "+1 678 614 2938"),
                       ("email_address", "support@gwlabs.app"), ("demo_user", ""), ("demo_password", ""),
                       ("notes", REVIEW_NOTES)]:
        write(review, key, value)
    print(f"{len(ASC) + len(COPIES)} locales, {len(list(SHOTS.glob('*/*.png')))} screenshots -> AppStore/")


if __name__ == "__main__":
    main()
