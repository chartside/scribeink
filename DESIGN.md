# ScribeInk design system

ScribeInk uses the same visual language as Chartside's other products, WhiteCoat Prep and
the disposition demo: a calm clinical teal, warm off-white surfaces, serif headings and
small uppercase monospace labels. The colours below were sampled from screenshots of
whitecoatprep.com (2026-11-06). Read this file before making any visual or UI change. The
rebrand that applies it to the app is roadmap sub-project 2.

## Colour

| Token | Hex | Used for |
|---|---|---|
| `brand` | `#1A6B5A` | Primary buttons, the hero band, active tab underline, links ("See all →"), key numbers, status dots, chart bars |
| `brandInk` | `#FFFFFF` | Text and icons on `brand` |
| `brandInkMuted` | `#D2F0E6` | Secondary text and hairlines on `brand` |
| `ink` | `#1D1D1F` | Headings and body text |
| `inkSecondary` | `#403F44` | Secondary body text |
| `inkMuted` | `#6A655F` | Labels, metadata, chip text |
| `canvas` | `#FAFAF8` | Window and page background; card header strips |
| `surface` | `#FFFFFF` | Cards, sheets, popovers |
| `surfaceSunken` | `#F4F5EF` | Footer bands, neutral chips ("Abandoned", "Ethical") |
| `hairline` | `#E7E6E1` | Card borders and dividers |
| `tint` | `#E9F5F1` | Info callouts ("MMI tips"), the credit pill |
| `tintBorder` | `#C3D6D2` | Border of `tint` boxes |
| `markTile` | `#101F26` | The logo tile |
| `accent` | `#E45630` | The logo's dot only. Never use it for warnings, errors or emphasis. |
| `notice` | `#F8F1E3` bg, `#8A6A1F` text | A safety banner across the top ("Synthetic demo. Not medical advice."). Approximated from the demo screenshot, so confirm the exact values. |

Dark mode is not shown on the site. A proposal to review once the colours are built into
the app: `canvas #121614`, `surface #1A1F1D`, `hairline #2A302D`, `ink #ECEDE9`,
`inkMuted #9AA39F`, `brand #3FA58C` (lifted so it stays readable on dark), and `tint`
becomes `brand` at 14% opacity.

## Type

- **Headings:** a bold transitional serif, for page titles ("Interview History"), card
  titles and hero copy. Use sentence case, and a short full stop is fine ("Prepare like it
  matters.").
- **Body and UI:** a clean humanist sans at regular weight; medium weight for buttons and
  list titles.
- **Labels:** an uppercase monospace with wide letter-spacing, in `inkMuted` or `brand`.
  It's used for eyebrows, section labels and timers ("READING PHASE 01:23 / 02:00",
  "STATION 2 · ETHICAL REASONING", "VOTES").
- **Fonts:** to be confirmed from the site's CSS. The closest freely licensed matches are
  Source Serif 4 (headings), Figtree or DM Sans (body) and JetBrains Mono or IBM Plex Mono
  (labels). On macOS, fall back to New York, SF Pro and SF Mono.

## Shape and layout

- **Cards:** `surface`, a 1px `hairline` border, about 14pt corner radius, no shadow, and
  generous padding (about 24pt). An optional header strip in `canvas`, divided by a
  hairline, carries mono labels and timers.
- **Buttons:** about 12pt radius, at least 44pt tall.
  - Primary: `brand` fill, white text.
  - On `brand` backgrounds: white fill with `brand` text, or a secondary button with a
    1.5pt light outline (`brandInkMuted`).
- **Chips:** `surfaceSunken`, about 6pt radius, `inkMuted` text.
- **Stat tiles:** a mono uppercase label above a large serif number. The first stat may
  use `brand`.
- **Tabs:** text tabs, the active one in `brand` with a 2pt underline over a hairline.
- **Bar meters** (votes, confidence): a `surfaceSunken` track with a `brand` fill and fully
  rounded ends. The count is right-aligned in mono, and the winning row's label is bold.
- **Icons:** outline style, about 2pt stroke, in `brand`, for example the heart or the
  video camera.

## Voice

- Plain, direct and calm, written to a clinician.
- Short sentences. No hype words, exclamation marks or emoji.
- Safety and status copy says what is true ("Synthetic demo. Not medical advice.").

## Applying it to the macOS app (sub-project 2)

- Define the colour tokens once, as named colours in the asset catalog (`Assets.xcassets`)
  with light and dark variants, and reference them through a single `Color` extension in
  the existing `DesignSystem/` folder. Never hard-code hex values in views.
- Map the type roles to `Font` helpers in `DesignSystem/` (`.scribeTitle`, `.scribeBody`,
  `.scribeLabel`).
- Upstream VoiceInk's accent colour and gradients are replaced, not mixed in.
