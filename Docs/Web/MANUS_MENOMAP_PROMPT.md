# Task: add MenoMap to gwlabs.app (app page, privacy, terms, clinicians, homepage)

MenoMap is a new GW Labs app: a menopause tracker for iPhone and Apple Watch (App Store ID `6817484445`, launching
October 2026). Add its pages to gwlabs.app **using the existing app pages as the template**, and add it to the homepage,
footer, structured data and llms.txt.

**The copy in `content/` is final and approved by Rob.** Every claim in it has been checked against the app. Don't
reword, shorten, reorder or "improve" it, and don't add claims of your own. In particular never add: "clinically
proven", "doctor-approved", "FDA", "HIPAA", "AI", "diagnose", "cure", "treat", testimonials, ratings, download counts or
review stars. If something here conflicts with how the site works, do the closest thing that keeps the copy intact and
tell Rob in your report.

## Attached files (upload the whole `MenoMap-web-kit` folder)

| File | What it is |
|---|---|
| `content/menomap-page.md` | The app page: head tags, every section's copy, the 9 screenshots with alt text, FAQ, JSON-LD. |
| `content/menomap-privacy.md` | The MenoMap privacy policy. |
| `content/menomap-terms.md` | The MenoMap terms of use. |
| `content/menomap-clinicians.md` | The page for clinicians. |
| `site/menomap/screens/01-today.webp` … `09-privacy.webp` | The 9 app screenshots, 645 × 1401, same size as the other app pages. |
| `site/menomap/icon-1024.png`, `icon-180.png` | The app icon (page icon and apple-touch-icon). |
| `site/icons/menomap.webp` | The 192 px homepage card icon. |
| `site/menomap/sample-notes.pdf`, `sample-notes-page1.webp` | A sample clinician PDF made from demo data, and an image of its first page. |
| `site/menomap/clinic-handout-a4.pdf`, `clinic-handout-letter.pdf` | The printable handout for clinics. |

Host images and PDFs the same way as for the other app pages (manuscdn URLs are fine). If the host can serve static
files under `/menomap/`, prefer those paths (for example `https://gwlabs.app/menomap/sample-notes.pdf`).

## Part 1. The app page: `/menomap.html`

Build it from `content/menomap-page.md`, **as a copy of the live `/wishlock.html`**: the same template, classes,
shared `gwl-header` / `gwl-footer` chrome, hero with the app icon, screenshot gallery, section styles, FAQ, closing
CTA and sticky download bar. Only the content changes. The App Store link on every download button is:

`https://apps.apple.com/app/apple-store/id6817484445?pt=117201882&ct=gw-menomap&mt=8`

**`/menomap` (no `.html`) must show this same page.** That short URL is printed on the app's share cards in 34
languages, on the clinic handout, and opened by the app itself. Either serve the page at both URLs with the canonical
pointing to `/menomap.html`, or 301-redirect `/menomap` to `/menomap.html`. It must never fall through to the homepage.

## Part 2. `/menomap/privacy`, `/menomap/terms`, `/menomap/clinicians`

Build each from its file in `content/`, in the same format as the live `/wishlock/privacy` (numbered sections,
same chrome). Titles:

- `/menomap/privacy` → `Privacy Policy — MenoMap | GW Labs` (this is the App Store privacy policy URL; App Review opens it)
- `/menomap/terms` → `Terms of Use — MenoMap | GW Labs`
- `/menomap/clinicians` → `MenoMap for Clinicians: Patient Symptom Notes | GW Labs`, with the sample image, the sample
  PDF link and both handout links working

Each page links back to `/menomap.html` ("MenoMap" in the breadcrumb or under the H1, as on `/wishlock/privacy`).

## Part 3. Homepage, footer, structured data, llms.txt

1. **Homepage app card** in the **Body & Looks** category (`data-cat="body"`), after Trough, same markup as the other
   cards:
   - Name: `MenoMap`
   - Tagline: `Log hot flashes in one tap and bring clear notes to your doctor.`
   - Icon: `/icons/menomap.webp` (192 px), glow `rgba(212, 85, 42, 0.4)`
   - Link: `/menomap.html`
   - The gold `Coming soon` badge (see step 6)
   The hero orbit stays exactly as it is (7 featured apps). Don't change any other card.
2. **Footer "Apps" list on every page:** add `MenoMap` → `/menomap.html` after Trough.
3. **Homepage JSON-LD `ItemList`:** add a `MobileApplication` for MenoMap after Trough, in the same shape as the others
   (name `MenoMap`, url `https://gwlabs.app/menomap.html`, image = the icon, applicationCategory `HealthApplication`,
   operatingSystem `iOS`), and renumber the positions to 1–15. No `downloadUrl` or `offers` until it's live (step 6).
4. **`/llms.txt`:** add this line at the end of the `## Body & Looks` list (after Trough), nothing else:
   `- [MenoMap](https://gwlabs.app/menomap.html): A menopause tracker app for iPhone and Apple Watch — log hot flashes and night sweats in one tap, see patterns in your own entries and bring a one-page summary to your clinician, with no account and no ads.`
5. **Studio pages:**
   - `/privacy`: in the list of apps with their own policies, add
     `MenoMap has its own privacy policy at /menomap/privacy, because it works with Apple Health data.`
     Don't change anything else on the page.
   - `/support`, "Subscription Help": after the Heal sentence, add
     `MenoMap Pro's Yearly plan includes a 7-day free trial for eligible new subscribers; Monthly has no trial, and Lifetime is a one-time purchase.`
6. **"Coming soon": check before you publish.** Run
   `curl -s "https://itunes.apple.com/lookup?id=6817484445&country=us"`.
   - `resultCount` 0 (not released yet): keep the gold `Coming soon` badge on the homepage card, and add the same badge
     next to the eyebrow in the app page hero. Keep the App Store buttons as specified; they start working on launch day.
   - `resultCount` 1 or more: no badge anywhere, and add `"downloadUrl": "https://apps.apple.com/app/id6817484445"` and
     `"offers": {"@type": "Offer", "price": "0", "priceCurrency": "USD"}` to MenoMap's `MobileApplication` in both the
     homepage ItemList and the app page JSON-LD.

## Part 4. Check before you report

Open each URL in a real browser (the site answers 200 for any path, so check the `<title>`, not the status code):

| URL | Expected `<title>` |
|---|---|
| `https://gwlabs.app/menomap.html` | `MenoMap: Menopause Tracker App for iPhone \| GW Labs` |
| `https://gwlabs.app/menomap` | the same page (or a 301 to it) |
| `https://gwlabs.app/menomap/privacy` | `Privacy Policy — MenoMap \| GW Labs` |
| `https://gwlabs.app/menomap/terms` | `Terms of Use — MenoMap \| GW Labs` |
| `https://gwlabs.app/menomap/clinicians` | `MenoMap for Clinicians: Patient Symptom Notes \| GW Labs` |

Also check: all 9 screenshots load with their alt text; the three PDFs download; the homepage shows 15 apps with the
MenoMap card under the Body & Looks chip; the footer lists MenoMap on every page; the JSON-LD on the homepage and the app
page passes https://validator.schema.org; nothing else on the site changed.

## Report back

1. The five URLs with the title you saw on each.
2. Screenshots of `/menomap.html` at 390 px and 1440 px wide, and of `/menomap/clinicians` at 390 px.
3. The iTunes lookup result from step 6 and what you did with the badge.
4. Where the images and PDFs are hosted (the URLs).
5. Anything you couldn't do exactly as written, and why.
