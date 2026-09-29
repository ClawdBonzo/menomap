# MenoMap — Visual Identity

Tokens live in `MenoMap/DesignSystem/MenoTheme.swift`. Do not invent a second palette.

## Idea
**A heat map of your own weather.** MenoMap draws your surges like a topographic map: warm contours where it ran hot, calm stone where it didn't. The brand color is **cool teal**, standing for relief, breath and the button you press. The data color is **ember**, used for heat and only for data. Their meanings never swap.

It should read as adult and editorial, like Oura or a well-set magazine, not a pink wellness app and not a clone of Apple Health.

## Color

| Token | Light | Dark | Use |
|---|---|---|---|
| `ground` | #F3EEE7 warm stone | #151311 warm charcoal | App background |
| `surface` | #FBF8F4 | #211E1B | Cards |
| `surfaceRaised` | #FFFFFF | #2B2724 | Sheets, pressed states |
| `ink` | #1E2524 | #F2ECE4 | Primary text |
| `inkSecondary` | #5E6663 | #B5ADA3 | Secondary text |
| `hairline` | #1E2524 @ 10% | #F2ECE4 @ 12% | Dividers, empty heat cells |
| `teal` | #0D6B66 | #52B8AE | Brand, primary buttons, breathing, relief |
| `tealSoft` | #DCEBE8 | #1C3431 | Teal backgrounds |
| `ember` | #D4552A | #F07A4C | **Data only**: heat levels 1–5 at 14 / 30 / 48 / 70 / 94% opacity |
| `danger` | #B3261E | #F2B8B5 | **Only** the bleeding-after-menopause banner and emergency copy |
| `night` | #0B0A09 with #C9503A text | same | Surge night mode (red-shifted, dim) |

Heat is always shown **with its number** (count or level). Intensity is never encoded by color alone, and never red vs green.

## Type
- **Headlines:** New York (`.fontDesign(.serif)`), semibold. Greeting, section titles, big stat numbers, share cards, PDF headings.
- **Everything else:** SF Pro. Numbers use `.monospacedDigit()`.
- **Sized for 45–60 readers:** body text is never below `.body`. The Surge button label is 30pt+ semibold. The full Dynamic Type range, including the accessibility sizes, must reflow (stacks switch to vertical at AX sizes).

## Shape and space
- 8-pt grid; card radius 20; button radius 16; minimum hit target 44pt (Surge button: 96pt tall).
- Cards are flat on the stone ground with a hairline border. No drop shadows except the Surge button, which gets a soft teal glow.

## Motion
- The breathing circle eases in and out on a 4-4-4 count.
- Heat cells fill in from left to right the first time they appear.
- Stat numbers count up.
- **Reduce Motion:** everything is instant and the breathing circle becomes a text countdown.
- No confetti, sparkles or bounce.

## Icon
Concentric contour rings (a topographic "heat map") in ember on warm stone, with a single teal contour closest to the center: the calm at the core of the heat. No flowers, no female silhouette, no thermometer.

## Voice
- **Straight** (default for safety, legal, Learn and the PDF): calm, plain and specific.
- **Wry** (stats, share cards, empty states): dry, warm and adult. "14 personal summers this week." "Peak hour: 3:12am. Rude." Never crude, never about bodies in a mocking way, never at the user's expense.

**Banned in any voice:** cure, treat, fix, balance hormones, diagnose, sisterhood, queen, goddess, journey, "you've got this", and emoji in UI copy.
