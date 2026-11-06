# ScribeInk identity and design: design

Date: 2026-11-06. Status: approved in conversation, awaiting written-spec review.

## Goal

ScribeInk becomes its own app: a **parallel install** next to upstream VoiceInk. Both can
be installed side by side and run at the same time without sharing anything. It looks like
Chartside's other products (`DESIGN.md`).

**Success means:**
- `ScribeInk.app` and `VoiceInk.app` coexist in `/Applications`, run together, and keep
  separate settings, history, models, Keychain items, permission grants and login items.
- Neither app's recording shortcut triggers the other.
- ScribeInk can never be replaced by an upstream VoiceInk update.
- Nothing in a default build sells or links to upstream VoiceInk, except the GPL
  attribution.
- Light and dark appearances use the `DESIGN.md` tokens, and the text pairs pass WCAG AA
  contrast.

## Roadmap context

This is sub-project 2. The operator set the order on 2026-11-06:

1. On-device only (done, chartside/scribeink#3).
2. **ScribeInk identity and design** (this spec).
3. Medical vocabulary and custom dictionary.
4. Template-driven notes.
5. ScribeInk's own updates, licensing and announcements.
6. `scribeink-ios` on-device work.

## Decisions (operator, 2026-11-06)

- **Clean start:** there is no migration from VoiceInk, and ScribeInk never reads
  VoiceInk's preferences, folders or Keychain.
- **Updater off** until sub-project 5 adds Chartside's own feed and key.
- **Upstream services off, code kept:** licensing and trial, remote announcements, the
  GitHub-star prompt, and upstream support links. Sub-project 5 deals with replacing them.
- **Fonts:** macOS system fonts only. New York for headings, SF Pro for body and SF Mono
  for labels. Nothing is bundled.
- **Icons:** generated placeholders in the WhiteCoat Prep style, replaced when final
  artwork exists.
- **Delivery:** one spec, two PRs. PR 1 changes identity; PR 2 changes the look.

## PR 1: identity (parallel install)

### What has to be separated

| Shared today | Change |
|---|---|
| Product file `VoiceInk.app` (`PRODUCT_NAME = $(TARGET_NAME)`) | `PRODUCT_NAME = ScribeInk` for the app target (Debug shows "ScribeInk Dev"). `PRODUCT_MODULE_NAME` stays `VoiceInk`, so Swift code and `@testable import VoiceInk` don't change. The Makefile builds and copies `ScribeInk.app` / `ScribeInk Dev.app`. |
| Bundle IDs `com.prakashjoshipax.VoiceInk`, `.dev`, `.RefineXPC`, `VoiceInkTests`, `VoiceInkUITests` | `com.chartside.ScribeInk`, `com.chartside.ScribeInk.dev`, `com.chartside.ScribeInk.RefineXPC`, `com.chartside.ScribeInkTests`, `com.chartside.ScribeInkUITests`. |
| `keychain-access-groups` hard-coded to `$(AppIdentifierPrefix)com.prakashjoshipax.VoiceInk` in both entitlements files | `$(AppIdentifierPrefix)com.chartside.ScribeInk`. |
| The old ID written out about 12 times in Swift (Keychain service, Application Support folder, logger subsystem, others) | One constant, `AppIdentity.bundleIdentifier`, read from `Bundle.main.bundleIdentifier`, with a fallback of `com.chartside.ScribeInk`. Every use derives from it. The `.dev` build gets its own folder automatically. |
| Refine XPC service name | Derived from the app's bundle ID, so a ScribeInk app can't reach VoiceInk's helper. |
| The default global recording shortcut | ScribeInk ships a default that differs from upstream VoiceInk's. The plan picks it from what the shortcut system supports, and onboarding shows it. |
| Launch at login | Registered under the new bundle ID. |
| `SUFeedURL` and `SUPublicEDKey` in `Info.plist` | Removed (see "Upstream services"). |

### What's renamed

**Only what users see:**
- Bundle display names.
- Menu items such as "Quit ScribeInk".
- Window titles.
- Permission prompts (`NSMicrophoneUsageDescription`, `NSAppleEventsUsageDescription` and any others).
- About.
- Every user-facing string in `Localizable.xcstrings` and in Swift string literals that says "VoiceInk" (about 236 catalog entries). "VoiceInk Refine" becomes "ScribeInk Refine", and so on.

**Unchanged:** Xcode target, folder, file and Swift type names (`VoiceInk.xcodeproj`,
`VoiceInkEngine`, `VoiceInkRefineXPC`). This keeps upstream merges workable. `CLAUDE.md`
records the rule.

### Upstream services

A new `UpstreamServices` policy (`VoiceInk/Infrastructure/Privacy/UpstreamServices.swift`),
in the same style as `ProviderPolicy`, has all flags off in default builds:
- **Updater:** `UpdaterViewModel` never starts the Sparkle updater. "Check for updates" is hidden, and About shows "Updates are not available yet."
- **Licensing:** no trial countdown, licence gating or Pro prompts. The licence screens are hidden. Licence code and the Polar client stay in the repo, unused.
- **Announcements:** `AnnouncementsService` doesn't fetch.
- **GitHub-star prompt:** not shown.
- **Support links and email:** point to `https://github.com/chartside/scribeink`.

### Attribution

- **About:** "ScribeInk is based on VoiceInk by Prakash Joshi Pax, licensed under GPL v3", linking to the upstream repository.
- **`README.md`:** rewritten for ScribeInk, with the same credit. `LICENSE` is unchanged.

### Icons

- **App icon:** a placeholder at every macOS `AppIcon.appiconset` size. It's a `#101F26` rounded tile with a white serif "SI" monogram and a small `#E45630` dot.
- **Menu-bar icon:** a monochrome template glyph.
- **Generation:** both come from a checked-in script (`scripts/generate-placeholder-icons.*`), so they can be regenerated or replaced.

## PR 2: the look

### Colour tokens

- **Named colours:** every token in the `DESIGN.md` colour table becomes a colour in `Assets.xcassets`, with light and dark variants: `brand`, `brandInk`, `brandInkMuted`, `ink`, `inkSecondary`, `inkMuted`, `canvas`, `surface`, `surfaceSunken`, `hairline`, `tint`, `tintBorder`, `markTile`, `accent`.
- **Dark values:** the dark-mode proposal in `DESIGN.md`. Any token it doesn't list is derived and recorded back into `DESIGN.md`.
- **Accent:** `AccentColor.colorset` becomes `brand`.

### `AppTheme`

The existing enums keep their names and are remapped, so the call sites don't change:
- **`Accent`:** derives from `brand`.
- **`Surface`:**
  - `window` → `canvas`
  - `card` → `surface`
  - `subtle` → `surfaceSunken`
  - `control` → `surface`
  - `materialCard` keeps its material, tinted toward `surface`.
- **`Border`:** derives from `hairline`.
- **`Selection`:** uses a tint of `brand`.
- **`Status`:** keeps the macOS system red, orange and green, so warnings stay recognisable. `accent` is never used for status.
- **`Data` and `Insights`:** a teal-led palette that keeps the series distinguishable.
- **Hard-coded colours:** the roughly 10 `Color(red:…)` uses move onto tokens.

### Typography

`AppTheme.Typography` has three roles:
- **`title`:** New York (`.serif` design), bold.
- **`body`:** SF Pro.
- **`label`:** SF Mono, uppercase, letter-spaced.

All three use text styles that scale with the system's accessibility text size. They're applied where the shared components and screens already declare headings and section labels.

### Shared components

These are restyled once, so every screen that uses them updates:
- **`AppSurfaces`:** about 14pt radius, a 1pt `hairline` border, no shadow.
- **`AppControls`:** a primary button in `brand` with about 12pt radius.
- **Chips:** `surfaceSunken` with `inkMuted` text.
- **Section labels and `CompactHeroSection`.**
- **`SidePanel`.**

No screen gets a new layout. Screen-by-screen redesign is out of scope.

## Verification

### Automated (container and CI)

`scripts/check-scribeink-identity.sh` runs in CI next to `check-on-device.sh`. It fails if any of these is true:
1. `com.prakashjoshipax` appears in `VoiceInk.xcodeproj/project.pbxproj`, any `*.plist`, any `*.entitlements` or any Swift file. An allow-list covers attribution text and upstream URLs.
2. The app target's `PRODUCT_NAME` isn't `ScribeInk`.
3. `VoiceInk/Info.plist` contains `SUFeedURL` or `SUPublicEDKey`.
4. A user-facing string (a `Localizable.xcstrings` value, a Swift `String(localized:)` or `Text("…")` literal, or a plist usage description) contains "VoiceInk" outside an allow-list: the attribution line, upstream links and code identifiers.

### Unit tests (existing `VoiceInkTests` target)

- `UpstreamServices` flags are all off in default builds.
- `AppIdentity.bundleIdentifier` matches `Bundle.main.bundleIdentifier`.
- Every token exists as a named colour in light and dark.
- These pairs meet WCAG AA, computed from the colour values: `ink` on `canvas`, `ink` on `surface`, `inkMuted` on `surface`, and `brandInk` on `brand`.

### On a Mac (`docs/qa/scribeink-identity-checklist.md`)

- **Parallel install:** with both apps installed and running, each keeps its own settings, history, models and Keychain. Each shortcut triggers only its own app, and launch at login is independent.
- **No upstream services:** "Check for updates" is gone, no licence or trial prompt appears, and no traffic goes to `tryvoiceink.com`, `polar.sh` or `beingpax.github.io` (watched with `nettop` or Little Snitch).
- **About:** shows the attribution.
- **Visual pass:** dashboard, settings, recorder and onboarding, in light and dark.

## Not changed by this sub-project

- The on-device rules from chartside/scribeink#3.
- Model downloads (still Hugging Face).
- Chartside updates, licensing and announcements (sub-project 5).
- `scribeink-ios`.
- Internal Xcode target, file and type names.
