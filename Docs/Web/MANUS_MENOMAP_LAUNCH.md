# MenoMap is live: launch update for gwlabs.app

MenoMap is now on the App Store: https://apps.apple.com/app/menomap-menopause-tracker/id6817484445
(App Store ID `6817484445`). Update the MenoMap pages and the homepage for launch. Keep the design, layout and all
other copy exactly as they are. Change only what's listed below.

## 1. Remove "Coming soon" everywhere

- Remove the gold `Coming soon` badge from the MenoMap card on the homepage, and from the hero of `/menomap.html`.
  Check the rendered page in a browser too, in case the badge is added by JavaScript.
- On the homepage card, use the same small `New` label style other recent apps use, if the site has one. If it
  doesn't, show no label.
- Every MenoMap download button keeps this exact link (it carries our campaign tracking):
  `https://apps.apple.com/app/apple-store/id6817484445?pt=117201882&ct=gw-menomap&mt=8`
- Homepage card button: `https://apps.apple.com/app/apple-store/id6817484445?pt=117201882&ct=gw-home-menomap&mt=8`

## 2. Smart App Banner and structured data

- In the `<head>` of `/menomap.html`, `/menomap/clinicians`, `/menomap/privacy` and `/menomap/terms`, the Apple Smart
  App Banner tag must be exactly:
  `<meta name="apple-itunes-app" content="app-id=6817484445">`
  `/menomap.html` currently has an `apple-itunes-app` tag. Replace it with the line above, don't add a second one.
- In the `SoftwareApplication` JSON-LD on `/menomap.html`, add or update
  `"downloadUrl": "https://apps.apple.com/app/id6817484445"` and `"offers": {"@type": "Offer", "price": "0", "priceCurrency": "USD"}`.
  Don't add ratings or reviews. There aren't any yet, and made-up ratings break Google's rules.

## 3. World Menopause Day strip (shows October 11–25 only)

Add a slim announcement strip at the top of `/menomap.html`, above the hero, in the page's accent color:

> **World Menopause Day, October 18:** try Two Weeks of Night Watch. One tap per night sweat, then clear notes for your
> appointment. [Get MenoMap](download link from step 1)

Show it only between 2026-10-11 and 2026-10-25 inclusive, using a small client-side date check in the visitor's local
time. Before or after those dates it must not render at all (no empty space). Make it dismissible with an ×.

## 4. Clinicians page

On `/menomap/clinicians`, in "For your practice: clinic codes", add this sentence after the first paragraph:

> MenoMap is available now on the App Store for iPhone (iOS 18 or later), with an optional Apple Watch app.

Add an App Store badge linking to
`https://apps.apple.com/app/apple-store/id6817484445?pt=117201882&ct=gw-clinicians&mt=8` under that sentence.

## 5. Review link

In the closing CTA of `/menomap.html`, keep "Already using MenoMap? Leave a review on the App Store", linking to
`https://apps.apple.com/app/id6817484445?action=write-review`.

## Check before you report

Use `curl` (no JavaScript) and a real browser:

```
curl -s https://gwlabs.app/menomap.html | grep -o '<meta name="apple-itunes-app"[^>]*>'   # exactly one, app-id=6817484445
curl -s https://gwlabs.app/menomap.html | grep -c 'Coming soon'                            # 0
curl -s https://gwlabs.app/ | grep -c 'Coming soon'                                        # 0
curl -s https://gwlabs.app/menomap.html | grep -o '"downloadUrl"[^,]*'
```

Also confirm in a browser:

1. No "Coming soon" anywhere on the homepage or the MenoMap pages, on desktop and on a phone-width window.
2. Every MenoMap download button opens the App Store listing.
3. The World Menopause Day strip shows today if today is between Oct 11 and Oct 25, and is absent otherwise. Change
   your computer's date or temporarily edit the check to test both cases, then put it back.
4. On an iPhone in Safari, `/menomap.html` shows Apple's Smart App Banner for MenoMap at the top.

Report the curl outputs and these four checks.
