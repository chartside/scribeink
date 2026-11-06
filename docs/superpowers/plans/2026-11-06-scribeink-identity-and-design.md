# ScribeInk identity and design: implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** ScribeInk installs and runs beside VoiceInk without sharing anything, sells
nothing upstream, and looks like `DESIGN.md`.

**Architecture:**
- **PR 1 (Tasks 1–5), identity:** a check script written first; a single `AppIdentity`
  constant replacing every hard-coded upstream ID; new bundle IDs, product name and
  entitlements; renamed user-visible strings; an `UpstreamServices` policy that switches off
  the updater, licensing, announcements and star prompt; attribution and placeholder icons.
- **PR 2 (Tasks 6–8), look:** `DESIGN.md` tokens become asset-catalog colours behind the
  existing `AppTheme` names, plus a `Typography` role set and restyled shared components.
- **Order:** PR 1 merges before PR 2 starts. Restart the branch from `main` between them.

**Tech Stack:** Swift / SwiftUI macOS app (`VoiceInk.xcodeproj`, synchronized folders), XCTest
(`VoiceInkTests`), bash and python3 scripts, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-11-06-scribeink-identity-and-design.md`

## Global Constraints

- **New bundle IDs:**
  - `com.chartside.ScribeInk` (Release)
  - `com.chartside.ScribeInk.dev` (Debug)
  - `com.chartside.ScribeInk.RefineXPC`
  - `com.chartside.ScribeInkTests`
  - `com.chartside.ScribeInkUITests`
- **Other new identifiers:**
  - Keychain group: `$(AppIdentifierPrefix)com.chartside.ScribeInk`.
  - iCloud container: `iCloud.com.chartside.ScribeInk`.
- **Product names:**
  - App target `PRODUCT_NAME`: `ScribeInk`. Debug display name: `ScribeInk Dev`.
  - `PRODUCT_MODULE_NAME` stays `VoiceInk`. Xcode target, folder, file and Swift type names
    don't change.
- **Clean start:** no code may read VoiceInk's preferences, folders or Keychain.
- **Exact copy:**
  - Attribution: "ScribeInk is based on VoiceInk by Prakash Joshi Pax, licensed under GPL v3".
  - Updates: "Updates are not available yet."
  - Support URL: `https://github.com/chartside/scribeink`.
- **Upstream code stays:** disable it, don't delete it. Every switched-off service is still
  in the repo.
- **Fonts:** system fonts only. New York (`.serif` design), SF Pro, SF Mono. Nothing bundled.
- **Colours:** come only from `DESIGN.md` tokens. `accent` (`#E45630`) is logo-only; `Status`
  keeps the macOS system red, orange and green.
- **Still in force:** the on-device rules (`CLAUDE.md` item 1), and
  `scripts/check-on-device.sh` must keep passing.
- **No project.pbxproj edits beyond build settings:** synchronized folders pick up new files.
- **No Swift toolchain in the agent container:** container checks are bash, python3 and grep.
  Every "Mac check" is listed unchecked in the PR.

## Review Focus

- **Dev and Release builds on one Mac.** `.dev` and Release must also stay apart from each
  other. Task 2's test asserts the support folder name equals the bundle ID, and the Mac
  checklist installs both.
- **Leftover upstream ID in a runtime path** (Application Support folder, Keychain service,
  iCloud). ScribeInk would silently read VoiceInk's data. The Task 1 script fails on any
  `com.prakashjoshipax` outside the allow-list, and Task 2 removes them all.
- **The licence gate removed but the trial banner or Pro badge still shown.** It would nag
  users to buy VoiceInk. Task 4's test covers every `UpstreamServices` flag, and the Mac
  checklist looks at the dashboard and settings.
- **Both apps recording on one keystroke.** Upstream has no built-in default shortcut;
  onboarding records one. Task 3 adds an onboarding hint, and the Mac checklist runs both
  apps with different shortcuts.
- **Dark mode contrast after the token switch.** Task 6's contrast test computes WCAG
  ratios for both appearances.

---

## PR 1: identity

### Task 1: The identity check script, written first so it fails today

**Files:**
- Create: `scripts/check-scribeink-identity.sh` (bash, calling python3 for JSON)
- Create: `scripts/scribeink-identity.allow`
- Modify: `.github/workflows/on-device-check.yml` (add a step that runs the new script)

**Interfaces:**
- Produces: `scripts/check-scribeink-identity.sh`. It exits 0 when clean and 1 otherwise,
  printing one `FAIL: <check>: <file>[:line]: <detail>` line per violation. Tasks 2–5 run it.

- [ ] **Step 1: Write the script.** It makes four checks, all against the allow-list file
  (lines of `<glob-or-path>\t<literal>`):
  1. `com.prakashjoshipax` appears in `VoiceInk.xcodeproj/project.pbxproj`, any `*.plist`,
     any `*.entitlements`, any `*.xcconfig`, any Swift file or the `Makefile`.
  2. The app target's `PRODUCT_NAME` isn't `ScribeInk`. Find the app target's build
     configurations, the two that have `PRODUCT_BUNDLE_IDENTIFIER` for the app, and require
     `PRODUCT_NAME = ScribeInk;`.
  3. `VoiceInk/Info.plist` contains `SUFeedURL` or `SUPublicEDKey`.
  4. "VoiceInk" appears in a user-facing string:
     - `Localizable.xcstrings` values (python3 `json`; every `stringUnit.value` and every key
       used as source text);
     - Swift `String(localized: "…")`, `Text("…")`, `Button("…")`, `Label("…")` and
       `.navigationTitle("…")` literals;
     - plist `*UsageDescription` and `CFBundleDisplayName` values.
- [ ] **Step 2: Seed the allow-list** with: the exact attribution sentence; `github.com/Beingpax`;
  `LICENSE`; and `docs/`.
- [ ] **Step 3: Run it on today's tree.**
  - Run: `bash scripts/check-scribeink-identity.sh; echo "exit=$?"`
  - Expected: `exit=1`, with many `FAIL: id` lines, a `FAIL: product-name`, a `FAIL: updater`
    and many `FAIL: string` lines. Record the counts in the report.
- [ ] **Step 4: Add a CI step** to `on-device-check.yml`, after the existing step. It runs
  `bash scripts/check-scribeink-identity.sh` with `continue-on-error: true` until Task 5
  removes that flag, so `main` stays green between tasks. Note this in the commit message.
- [ ] **Step 5: Commit.**

### Task 2: App identity, bundle IDs, entitlements and every hard-coded upstream ID

**Files:**
- Create: `VoiceInk/App/Configuration/AppIdentity.swift`
- Test: `Tests/VoiceInkTests/AppIdentityTests.swift`
- Modify: `VoiceInk.xcodeproj/project.pbxproj` (build settings only: the `PRODUCT_BUNDLE_IDENTIFIER`
  lines shown by `grep -n PRODUCT_BUNDLE_IDENTIFIER`, the app target's `PRODUCT_NAME`, and
  `INFOPLIST_KEY_CFBundleDisplayName` = `ScribeInk` / `ScribeInk Dev`)
- Modify: `VoiceInk/VoiceInk.entitlements`, `VoiceInk/VoiceInk.debug.entitlements` (iCloud
  container and Keychain group), and `VoiceInk/VoiceInk.local.entitlements` if it names
  either
- Modify: `Shared/VoiceInkRefineXPCProtocol.swift:3-4` (`com.chartside.ScribeInk.RefineXPC`)
- Modify: `Makefile` (`RUN_APP_NAME`, `LOCAL_APP_NAME`, the `Release/VoiceInk.app` product
  path → `ScribeInk`, `ScribeInk Dev`, `ScribeInk Cloud Dev`), and `BUILDING.md` to match
- Modify: every Swift file that `grep -rn "com.prakashjoshipax" --include=*.swift VoiceInk Shared VoiceInkRefineXPC` lists (about 100 lines)

**Interfaces:**
- Produces:
  ```swift
  enum AppIdentity {
      static let fallbackBundleIdentifier = "com.chartside.ScribeInk"
      static var bundleIdentifier: String          // Bundle.main.bundleIdentifier ?? fallback
      static var applicationSupportFolderName: String  // == bundleIdentifier
      static var loggerSubsystem: String           // bundleIdentifier.lowercased()
      static func queueLabel(_ suffix: String) -> String  // "\(loggerSubsystem).\(suffix)"
      static var keychainService: String           // bundleIdentifier
      static var localKeychainService: String      // "\(bundleIdentifier).Local"
      static let iCloudContainerIdentifier = "iCloud.com.chartside.ScribeInk"
  }
  ```

- [ ] **Step 1: Write failing tests** in `AppIdentityTests.swift`:
  - `testBundleIdentifierMatchesMainBundle`: `AppIdentity.bundleIdentifier == Bundle.main.bundleIdentifier ?? AppIdentity.fallbackBundleIdentifier`.
  - `testSupportFolderIsBundleIdentifier`: `AppIdentity.applicationSupportFolderName == AppIdentity.bundleIdentifier`.
  - `testNoUpstreamIdentifier`: none of `bundleIdentifier`, `keychainService`,
    `localKeychainService`, `loggerSubsystem` or `iCloudContainerIdentifier` contains
    `prakashjoshipax`.
- [ ] **Step 2: Implement `AppIdentity.swift`** to the interface above.
- [ ] **Step 3: Replace every hard-coded ID** using these mappings:
  - `Logger(subsystem: "com.prakashjoshipax.voiceink", …)` → `Logger(subsystem: AppIdentity.loggerSubsystem, …)`
  - `DispatchQueue(label: "com.prakashjoshipax.voiceink.X")` and thread names → `AppIdentity.queueLabel("X")`
  - `.appendingPathComponent("com.prakashjoshipax.VoiceInk"…)` → `.appendingPathComponent(AppIdentity.applicationSupportFolderName…)`
  - `KeychainService.swift:28/32` services → `AppIdentity.localKeychainService` / `AppIdentity.keychainService`
  - `VoiceInk.swift:250` iCloud identifier → `AppIdentity.iCloudContainerIdentifier`
  - `WindowManager.swift:48` → `"\(AppIdentity.loggerSubsystem).mainWindow"`
  - `UpdaterViewModel.swift:78` error domain → `"\(AppIdentity.loggerSubsystem).updates"`
  - `LogExporter.swift:8` `subsystem` → `AppIdentity.loggerSubsystem`. Its log export then
    filters on the new subsystem.

  Where a stored property's initialiser can't call a computed static (it can; these are
  static vars), keep the mapping as-is.
- [ ] **Step 4: Update build settings, entitlements, XPC name and Makefile** as listed under
  Files.
  - The embedded XPC service is only reachable from its own app, so a constant
    `com.chartside.ScribeInk.RefineXPC` replaces the spec's "derived from the app bundle ID".
    It also keeps Debug and Release working, since both embed the same service ID. Record
    this departure from the spec in the commit.
  - `make local` and `make local-cloud` copy `ScribeInk.app` / `ScribeInk Cloud Dev.app`.
- [ ] **Step 5: Container check.**
  - Run: `bash scripts/check-scribeink-identity.sh 2>&1 | grep -c "FAIL: id"`. Expected: `0`.
  - Run: `bash scripts/check-on-device.sh`. Expected: OK. Update `scripts/on-device-hosts.allow`
    paths only if a file moved.
  - Run: `grep -n "PRODUCT_NAME = ScribeInk" VoiceInk.xcodeproj/project.pbxproj | wc -l`.
    Expected: `2`.
- [ ] **Step 6: Mac check (operator).** `make local` produces `~/Downloads/ScribeInk.app`, it
  launches, and data lands in `~/Library/Application Support/com.chartside.ScribeInk`.
  `xcodebuild test … -only-testing:VoiceInkTests` passes.
- [ ] **Step 7: Commit.**

### Task 3: User-visible rename

**Files:**
- Modify: `VoiceInk/Info.plist` (every `*UsageDescription` and any `CFBundleName`/display string)
- Modify: `VoiceInk/Localizable.xcstrings` (every source string and translation value containing "VoiceInk")
- Modify: Swift files whose user-facing literals contain "VoiceInk". Task 1's script lists them.
- Modify: the onboarding shortcut step (the view that records `primaryRecording`; find it from
  `OnboardingFlowController.swift:518` and `coordinator.experienceShortcutAction`)

- [ ] **Step 1: Replace "VoiceInk" with "ScribeInk"** in every user-facing string Task 1's
  check 4 reports.
  - **xcstrings keys:** for a key that is itself the source text, update the key and every
    reference to it in Swift in the same edit, so lookups don't break. Use a python3 script
    run once from the scratchpad. Don't commit the script.
  - **Leave alone:** code identifiers, file names, log messages, comments, and the
    attribution sentence.
- [ ] **Step 2: Add the onboarding hint.** This departs from the spec, which says
  "ScribeInk ships a default that differs from upstream's". The code has no built-in default
  recording shortcut: onboarding makes the user record one, so there's nothing to change.
  The hint stops both apps sharing a shortcut. Under the shortcut recorder:
  `String(localized: "Using VoiceInk too? Choose a different shortcut so both apps don't record at once.")`.
  Allow-list this exact sentence in `scripts/scribeink-identity.allow`.
- [ ] **Step 3: Container check.**
  - Run: `bash scripts/check-scribeink-identity.sh 2>&1 | grep -c "FAIL: string"`. Expected: `0`.
  - Run: `python3 -c "import json;json.load(open('VoiceInk/Localizable.xcstrings'))"`.
    Expected: no error.
- [ ] **Step 4: Mac check (operator).** The menu bar shows "Quit ScribeInk", the permission
  prompts say ScribeInk, and onboarding shows the hint.
- [ ] **Step 5: Commit.**

### Task 4: Switch off upstream services

**Files:**
- Create: `VoiceInk/Infrastructure/Privacy/UpstreamServices.swift`
- Test: `Tests/VoiceInkTests/UpstreamServicesTests.swift`
- Modify: `VoiceInk/Info.plist` (delete the `SUFeedURL` and `SUPublicEDKey` keys)
- Modify: `VoiceInk/App/Updates/UpdaterViewModel.swift` (no updater start; `checkForUpdates`
  does nothing; expose `isAvailable`)
- Modify: `VoiceInk/App/MenuBar/MenuBarView.swift:158` and `UpdaterViewModel.swift:129`
  (hide "Check for Updates")
- Modify: `VoiceInk/App/Navigation/ContentView.swift:111` (no `LicenseManagementView`),
  `VoiceInk/Features/Dashboard/Views/DashboardContent.swift:500-515` (no `TrialMessageView`),
  plus any Pro badge or upsell that `grep -rn "VoiceInk Pro\|licenseState\|TrialMessageView" VoiceInk/Features VoiceInk/App` lists
- Modify: `VoiceInk/Infrastructure/RemoteConfig/AnnouncementsService.swift` (no fetch) and its
  start call in `VoiceInk/App/VoiceInk.swift`
- Modify: `VoiceInk/Features/Dashboard/State/GitHubStarPromptCoordinator.swift` and the views
  that show `GitHubStarPromptCard`
- Modify: `VoiceInk/Features/Settings/Support/EmailSupport.swift` and the other support and
  "website" links that `grep -rn "tryvoiceink.com\|github.com/Beingpax" VoiceInk --include=*.swift`
  lists, excluding the attribution link → the support URL

**Interfaces:**
- Produces:
  ```swift
  enum UpstreamServices {
      static let updatesEnabled: Bool        // false
      static let licensingEnabled: Bool      // false
      static let announcementsEnabled: Bool  // false
      static let starPromptEnabled: Bool     // false
      static let supportURL: URL             // https://github.com/chartside/scribeink
  }
  ```
  All four flags are plain `false` constants. There's no build flag; sub-project 5 replaces
  them.

- [ ] **Step 1: Write failing tests:**
  - `testAllUpstreamServicesOff`: the four flags are `false`.
  - `testSupportURL`: `supportURL.absoluteString == "https://github.com/chartside/scribeink"`.
  - `testUpdaterUnavailable`: `UpdaterViewModel().isAvailable == false`. Construct it the way
    the app does; if its initialiser needs dependencies, test the static the view model reads
    instead.
- [ ] **Step 2: Implement the policy and gate each call site** listed under Files.
  - **Licensing off** means the app behaves as fully licensed: no feature is limited, and no
    licence or Polar network call is made. Find the single place the licence state is read
    for feature gating (from `LicenseViewModel.licenseState`) and treat it as licensed when
    `!UpstreamServices.licensingEnabled`.
  - **About** shows "Updates are not available yet." in place of the update button.
- [ ] **Step 3: Container check.**
  - Run: `bash scripts/check-scribeink-identity.sh 2>&1 | grep -c "FAIL: updater"`. Expected: `0`.
  - Run: `grep -rn "tryvoiceink.com" VoiceInk --include=*.swift | grep -v "UpstreamServices\|#if"`.
    Expected: only lines the remaining gated code still needs, each listed in the report.
- [ ] **Step 4: Mac check (operator).**
  - No "Check for Updates", trial banner or licence screen.
  - With `nettop`, no traffic to `tryvoiceink.com`, `polar.sh` or `beingpax.github.io` at
    launch or while using the app.
- [ ] **Step 5: Commit.**

### Task 5: Attribution, placeholder icons, docs and turning on the CI gate

**Files:**
- Modify: the About surface (find it via `grep -rn "About" VoiceInk/App VoiceInk/Features/Settings --include=*.swift`)
- Modify: `README.md` (rewritten for ScribeInk)
- Create: `scripts/generate-placeholder-icons.py` (python3 with Pillow; takes `--font PATH`)
- Modify: `VoiceInk/Assets.xcassets/AppIcon.appiconset/*` and `menuBarIcon.imageset/*`
- Create: `docs/qa/scribeink-identity-checklist.md`
- Modify: `CLAUDE.md` (an Identity section with the bundle IDs and the "internal names stay"
  rule); `.github/workflows/on-device-check.yml` (remove `continue-on-error`)

- [ ] **Step 1: Attribution.** Add the attribution sentence to About, linking
  `https://github.com/Beingpax/VoiceInk`, next to the support URL. Rewrite `README.md`:
  - what ScribeInk is (on-device clinical scribe, macOS, GPL v3);
  - build (`make local`);
  - the attribution;
  - links to `DESIGN.md`, `CLAUDE.md` and the QA checklists.

  Keep any upstream copyright line.
- [ ] **Step 2: The icon script.**
  - **App icon:** draws a `#101F26` rounded square (macOS squircle-ish radius of 22.5%) with
    a white "SI" in the given serif font and a `#E45630` dot near the top right of the "I".
    It writes every PNG size `AppIcon.appiconset/Contents.json` lists, keeping the existing
    file names.
  - **Menu-bar glyph:** a black-on-transparent "SI" template, written at the sizes
    `menuBarIcon.imageset` lists.
  - **Run it** in the container with `--font /usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf`,
    or any available serif bold, and commit the PNGs.
- [ ] **Step 3: The QA checklist** has the spec's "On a Mac" items verbatim, plus:
  - Dev and Release installed together stay separate.
  - Onboarding shows the shortcut hint.
- [ ] **Step 4: `CLAUDE.md` and CI.** Add the Identity section. Remove `continue-on-error`
  from the identity step.
- [ ] **Step 5: Container check.**
  - Run: `bash scripts/check-scribeink-identity.sh; echo "exit=$?"`. Expected: `exit=0`.
  - Run: `bash scripts/check-on-device.sh`. Expected: OK.
  - Run: `python3 -c "import json;json.load(open('VoiceInk/Assets.xcassets/AppIcon.appiconset/Contents.json'))"`.
    Expected: no error.
- [ ] **Step 6: Commit, then open PR 1.** Merge PR 1 before Task 6.

## PR 2: the look (start from `main` after PR 1 merges)

### Task 6: Colour tokens in the asset catalog, with a contrast test

**Files:**
- Create: one `Assets.xcassets/<token>.colorset/Contents.json` per token: `brand`, `brandInk`,
  `brandInkMuted`, `ink`, `inkSecondary`, `inkMuted`, `canvas`, `surface`, `surfaceSunken`,
  `hairline`, `tint`, `tintBorder`, `markTile`, `accent`. Each has `universal` plus a
  `luminosity: dark` appearance, as sRGB components.
- Modify: `Assets.xcassets/AccentColor.colorset/Contents.json` (= `brand` light and dark)
- Modify: `DESIGN.md` (record every dark value used, including the ones derived here)
- Test: `Tests/VoiceInkTests/DesignTokensTests.swift`

**Interfaces:**
- Produces: named colours loadable as `NSColor(named: "<token>")` and `Color("<token>")`.
  These are the exact names Task 7 uses.

- [ ] **Step 1: Write failing tests:**
  - `testEveryTokenExists`: for each of the 14 names, `NSColor(named:)` is non-nil.
  - `testContrastAA`: for the light appearance (`NSAppearance(named: .aqua)`) and the dark
    appearance (`.darkAqua`), resolve each colour within `appearance.performAsCurrentDrawingAppearance`
    and compute the WCAG 2.x contrast ratio. Assert at least 4.5 for exactly four pairs:
    `ink` on `canvas`, `ink` on `surface`, `inkMuted` on `surface`, and `brandInk` on
    `brand`. Borders are exempt.

    Put the contrast helper (`relativeLuminance`, `contrastRatio`) in the test file.
- [ ] **Step 2: Write the colour sets.**
  - **Light values:** exactly as in `DESIGN.md`.
  - **Dark values:** from the `DESIGN.md` proposal (`canvas #121614`, `surface #1A1F1D`,
    `hairline #2A302D`, `ink #ECEDE9`, `inkMuted #9AA39F`, `brand #3FA58C`; `tint` = `brand`
    at 14% opacity).
  - **Unlisted dark tokens:** chosen so the contrast test passes. Record them in `DESIGN.md`.
- [ ] **Step 3: Container check.**
  - Run: `for f in VoiceInk/Assets.xcassets/*.colorset/Contents.json; do python3 -c "import json,sys;json.load(open(sys.argv[1]))" "$f" || echo BAD $f; done`.
    Expected: no `BAD`.
  - Run a python3 recomputation of the four contrast pairs from the JSON values, for both
    appearances. Expected: every ratio ≥ 4.5; print them in the report.
- [ ] **Step 4: Mac check (operator).** `-only-testing:VoiceInkTests/DesignTokensTests` passes.
- [ ] **Step 5: Commit.**

### Task 7: Remap `AppTheme`, add `Typography` and move hard-coded colours onto tokens

**Files:**
- Modify: `VoiceInk/DesignSystem/Theme/AppTheme.swift`
- Modify: each file in `grep -rn "Color(red:" VoiceInk --include=*.swift` (about 10 lines)

**Interfaces:**
- Consumes: Task 6 colour names.
- Produces: an unchanged `AppTheme` surface API (every existing member keeps its name and
  type), plus:
  ```swift
  extension AppTheme {
      enum Palette { static let brand, brandInk, brandInkMuted, ink, inkSecondary, inkMuted,
                     canvas, surface, surfaceSunken, hairline, tint, tintBorder, markTile, accent: Color }
      enum Typography {
          static func title(_ style: Font.TextStyle = .title2) -> Font   // .system(style, design: .serif).weight(.bold)
          static func body(_ style: Font.TextStyle = .body) -> Font      // .system(style)
          static func label(_ style: Font.TextStyle = .caption) -> Font  // .system(style, design: .monospaced)
      }
  }
  extension View { func scribeLabelStyle() -> some View }  // uppercase + tracking(1.2) + Palette.inkMuted
  ```

- [ ] **Step 1: Remap members** as the spec's "AppTheme" section lists.
  - `Accent.primary` → `Palette.brand`. The opacity variants keep their multipliers.
  - `Surface.window` → `canvas`, `card` → `surface`, `subtle` → `surfaceSunken`,
    `control` → `surface`. `materialCard` stays a material, tinted with `surface`.
  - `Border.subtle`, `card` and `control` → `hairline` (opacity as today).
  - `Selection` → `brand` tints.
  - `Status`: unchanged.
  - `Data` and `Insights`: a teal-led series — `brand`, `brand` at 60%, `inkSecondary`,
    `tintBorder`, plus the system yellow and purple kept for distinguishability.
- [ ] **Step 2: Move each `Color(red:…)`** onto the closest `Palette` token. Note each mapping
  in the report.
- [ ] **Step 3: Container check.**
  - Run: `grep -rn "Color(red:" VoiceInk --include=*.swift | wc -l`. Expected: `0`, or only
    lines justified in the report (for example, asset-independent drawing in recorder
    visualisers).
  - Run: `bash scripts/check-on-device.sh && bash scripts/check-scribeink-identity.sh`.
    Expected: both pass.
- [ ] **Step 4: Mac check (operator).** It builds. The dashboard, settings and recorder show
  teal accents and warm surfaces in light and dark.
- [ ] **Step 5: Commit.**

### Task 8: Restyle shared components, with a preview catalogue

**Files:**
- Modify: `VoiceInk/DesignSystem/Surfaces/AppSurfaces.swift`, `Components/AppControls.swift`,
  `Components/CompactHeroSection.swift`, `Overlays/SidePanel.swift`, and the chip and
  section-label views those files or `Components/` define
- Create: `VoiceInk/DesignSystem/DesignCatalogPreview.swift` (`#Preview` only, Debug)
- Modify: `docs/qa/scribeink-identity-checklist.md` (visual pass section)

**Interfaces:**
- Consumes: `AppTheme.Palette`, `AppTheme.Typography`, `scribeLabelStyle()` from Task 7.

- [ ] **Step 1: Restyle:**
  - **Cards:** `surface` fill, 14pt continuous corner radius, 1pt `hairline` stroke, no
    shadow, 24pt default padding.
  - **Primary button:** `brand` fill with `brandInk` text, 12pt radius, at least 44pt tall.
  - **Secondary button:** `hairline` outline.
  - **Chips:** `surfaceSunken` fill, `inkMuted` text, 6pt radius.
  - **Section labels:** `scribeLabelStyle()`.
  - **Titles** in `CompactHeroSection` and `SidePanel` headers: `Typography.title()`.

  Change component internals only; call sites don't change.
- [ ] **Step 2: Write the preview catalogue.** Each token swatch, every component state, and
  light and dark side by side via `.environment(\.colorScheme, …)`.
- [ ] **Step 3: Container check.** Run `git diff --stat main -- VoiceInk | tail -1`, and
  confirm in the report that no file outside `DesignSystem/` changed in this task. Run both
  check scripts.
- [ ] **Step 4: Mac check (operator).** The checklist's visual pass covers dashboard,
  settings, recorder and onboarding, in light and dark.
- [ ] **Step 5: Commit, then open PR 2.**
