# Follow-up: MenoMap link previews

The MenoMap pages look right in the browser. One problem: `/menomap`, `/menomap/clinicians`, `/menomap/privacy` and
`/menomap/terms` send the **homepage's HTML** (title "Focused iPhone Apps from an Independent iOS Studio") until
JavaScript runs. Link previews in Messages, Mail, WhatsApp and Slack don't run JavaScript, so a MenoMap link shows the
generic homepage card. The app sends `/menomap/clinicians` to patients' doctors, so this preview matters.

Change nothing else on the site.

1. **`/menomap`:** a real server-side **301 redirect** to `/menomap.html` (not a client-side redirect).
2. **`/menomap/clinicians`, `/menomap/privacy`, `/menomap/terms`:** the HTML the server sends (before any JavaScript)
   must contain that page's own head tags. Make them static pages like `/places-ive-had-sex.html`, or have the host
   inject per-route head tags, whichever the site supports. The visible pages stay exactly as they are now.

| Route | `<title>` and `og:title` | `meta description` and `og:description` | `og:image` |
|---|---|---|---|
| `/menomap/clinicians` | `MenoMap for Clinicians: Patient Symptom Notes \| GW Labs` | `What's in a patient's MenoMap notes, how to read them, a sample PDF, and free clinic codes for your practice.` | the clinician sample image (`sample-notes-page1.webp` URL) |
| `/menomap/privacy` | `Privacy Policy — MenoMap \| GW Labs` | `MenoMap has no account, no ads and no analytics. Your health data stays on your iPhone.` | the MenoMap app icon (1024 PNG URL) |
| `/menomap/terms` | `Terms of Use — MenoMap \| GW Labs` | `Terms of use for MenoMap, a menopause tracker and education tool that doesn't diagnose or treat.` | the MenoMap app icon (1024 PNG URL) |

Also add `twitter:card` (`summary_large_image` for clinicians, `summary` for the other two), and a canonical URL for
each route.

## Check before you report

Use `curl` (no JavaScript), not a browser:

```
curl -sI https://gwlabs.app/menomap                     # 301, Location: /menomap.html
curl -s https://gwlabs.app/menomap/clinicians | grep -o '<title>[^<]*'
curl -s https://gwlabs.app/menomap/privacy | grep -o '<title>[^<]*'
curl -s https://gwlabs.app/menomap/terms | grep -o '<title>[^<]*'
```

Each `<title>` must be the one in the table. Report the four outputs, and confirm the pages still look the same in a
browser.
