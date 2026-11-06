# On-device only: implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A default ScribeInk build can't select or reach any cloud transcription or cloud AI
provider, and the concrete cloud transcription code is not compiled in.

**Architecture:**
- A compile-time flag `CLOUD_PROVIDERS` (absent by default) wraps the concrete cloud
  transcription files.
- One `ProviderPolicy` decides what's allowed, and `LocalEndpoint` decides which hosts may
  be reached.
- Both are enforced in the pickers and at the two points where requests are sent: transcription
  `TranscriptionServiceRegistry.service(for:)` and enhancement
  `AIChatCompletionService.performChatCompletion`.
- A bash check script plus a CI workflow keep it that way.

**Tech Stack:** Swift 6 / SwiftUI macOS app (Xcode project `VoiceInk.xcodeproj`), XCTest,
bash, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-11-06-on-device-only-design.md`

## Global Constraints

- **The flag:** `CLOUD_PROVIDERS` is absent in every existing configuration (Debug,
  Release, `make local`, `make release`). Only `CloudBuild.xcconfig` / `make local-cloud`
  add it.
- **Disable, don't delete:** upstream cloud code stays in the repo. Wrap it; never remove
  it.
- **Allowed when `allowsCloud == false`:**
  - Transcription (`ModelProvider`): `.whisper`, `.fluidAudio`, `.transcribeCpp`,
    `.nativeApple`, `.custom`.
  - Enhancement (`AIProvider`): `.voiceInkRefine`, `.ollama`, `.custom`.
  - Everything else is denied, `.localCLI` included.
- **Loopback means:** host `localhost`, any IPv4 in `127.0.0.0/8`, or `::1`. Parsed host
  only, never a substring match.
- **Accepted hosts:** stored as lower-cased strings in the `UserDefaults` key
  `acceptedRemoteHosts`.
- **Exact copy:**
  - Warning: "This sends audio or transcripts containing patient information to {host}.
    Only use a server you control inside your clinic."
  - Blocked state: "Choose an on-device model".
  - Refusal: "Remote endpoint not confirmed".
  - Remote label: "Remote: {host}".
- **Never touched:** saved API keys (never read, sent or deleted by new code); updates,
  licensing, announcements and model downloads.
- **Repo rules:** GPL v3 headers kept; no competitor product names; no PHI in tests.
- **Swift can't be built in the agent container.** Each task says which checks run in the
  container (bash and grep) and which run on a Mac (`xcodebuild`). A task whose Mac step
  hasn't run is "done pending Mac build" and must be listed as such in the PR.

## Review Focus

- **Look-alike hosts:** `http://localhost.evil.com`, `http://127.0.0.1.nip.io`,
  `http://0.0.0.0:11434` and `http://192.168.1.20:11434` must be refused when not
  accepted. Covered by Task 2's tests.
- **Case and port of an accepted host:** accepting `Server.Local` must permit
  `http://server.local:8080/v1`, and a different host must warn again. Covered by Task 2's
  tests.
- **Endpoint edited outside the UI** (`defaults write … ollamaBaseURL`): must be refused at
  dispatch, not only in the settings field. Covered by Task 5's dispatch test.
- **A mode with its own provider or model:** a per-mode cloud selection must hit the same
  blocked path as the global one. Task 7 checks the resolved runtime configuration, not
  the global setting.
- **Custom transcription endpoint:** it no longer goes through `CloudTranscriptionService`
  (compiled out). Task 4's adapter must keep transcribing to a localhost Whisper server
  and must refuse an unconfirmed remote one.

---

### Task 1: The on-device check script (written first, fails on today's code)

**Files:**
- Create: `scripts/check-on-device.sh`
- Create: `scripts/on-device-hosts.allow`

**Interfaces:**
- Produces: `scripts/check-on-device.sh` exits 0 when all checks pass, 1 otherwise, and
  prints one `FAIL: <check>: <file>[: detail]` line per violation. Tasks 4 and 9 run it.

- [ ] **Step 1: Write the script.** It runs from the repo root and makes three checks:
  1. **Wrapped files.** Each file in a hard-coded `EXCLUDED` list must have
     `#if CLOUD_PROVIDERS` as its first non-blank, non-comment line and `#endif` as its
     last non-blank line. The list:
     - in `VoiceInk/Infrastructure/Providers/Transcription/Cloud/`:
       `AssemblyAIProvider`, `CartesiaProvider`, `DeepgramProvider`, `ElevenLabsProvider`,
       `GeminiProvider`, `GroqProvider`, `MistralProvider`, `OpenRouterProvider`,
       `SonioxProvider`, `SpeechmaticsProvider`, `XAIProvider`, `CloudTranscriptionService`;
     - every `*.swift` file in `…/Cloud/Streaming/`.
  2. **No stray references.** No Swift file outside `…/Transcription/Cloud/` may mention
     a type defined in the `EXCLUDED` files unless it's in `GUARDED_CALL_SITES`. Types are
     extracted with
     `grep -hoE '^(final |public |private )?(class|struct|enum|protocol|actor) [A-Za-z0-9_]+'`.
     `GUARDED_CALL_SITES` holds `Features/Recording/Workflows/TranscriptionServiceRegistry.swift`
     and `Features/ModelLibrary/State/TranscriptionModelManager.swift`; each must contain
     `#if CLOUD_PROVIDERS`.
  3. **No new hosts.** Every `https://<host>` in `VoiceInk/**/*.swift` must appear as a
     `<relative path> <host>` line in `scripts/on-device-hosts.allow`. Files whose first
     code line is `#if CLOUD_PROVIDERS` are skipped.
- [ ] **Step 2: Generate the allow-list.** Run
  `grep -rhoE 'https://[A-Za-z0-9.-]+' --include=*.swift VoiceInk` per file, sort it
  uniquely, and write `path host` pairs to `scripts/on-device-hosts.allow`. Put a header
  comment above them: "Hosts present at upstream 5c95ff9. Add a line only with operator
  approval."
- [ ] **Step 3: Run it on today's tree.**
  - Run: `bash scripts/check-on-device.sh; echo "exit=$?"`
  - Expected: `exit=1` with 21 `FAIL: wrapped` lines and `FAIL: references` lines for
    `TranscriptionServiceRegistry.swift`, `TranscriptionModelManager.swift` and
    `AIService.swift` (it uses `OpenRouterCatalogStore`). No `FAIL: hosts` lines.
- [ ] **Step 4: Commit.**
  ```bash
  git add scripts/check-on-device.sh scripts/on-device-hosts.allow
  git commit -m "Add on-device check script (fails until cloud code is gated)"
  ```

### Task 2: `ProviderPolicy` and `LocalEndpoint`, with unit tests

**Files:**
- Create: `VoiceInk/Infrastructure/Privacy/LocalEndpoint.swift` (Foundation only)
- Create: `VoiceInk/Infrastructure/Privacy/ProviderPolicy.swift`
- Test: `Tests/ScribeInkTests/ProviderPolicyTests.swift`
- Modify: `VoiceInk.xcodeproj/project.pbxproj` (add the two files to the VoiceInk target)

**Interfaces:**
- Produces:
  ```swift
  enum ProviderPolicy {
      static let allowsCloud: Bool                       // true only under #if CLOUD_PROVIDERS
      static func isAllowed(_ p: ModelProvider, allowsCloud: Bool = ProviderPolicy.allowsCloud) -> Bool
      static func isAllowed(_ p: AIProvider, allowsCloud: Bool = ProviderPolicy.allowsCloud) -> Bool
  }
  enum ProviderPolicyError: LocalizedError, Equatable {
      case providerNotAllowed(String)                    // provider display name
      case remoteEndpointNotConfirmed(host: String)      // errorDescription: "Remote endpoint not confirmed"
  }
  enum LocalEndpoint {
      static let acceptedHostsKey = "acceptedRemoteHosts"
      static func isLoopback(_ url: URL) -> Bool
      static func acceptedHosts(_ defaults: UserDefaults = .standard) -> Set<String>
      static func accept(host: String, defaults: UserDefaults = .standard)   // stores lower-cased
      static func isPermitted(_ url: URL, allowsCloud: Bool = ProviderPolicy.allowsCloud,
                              defaults: UserDefaults = .standard) -> Bool
      static func requirePermitted(_ url: URL) throws    // throws .remoteEndpointNotConfirmed
  }
  ```
  `isPermitted` = `allowsCloud || isLoopback(url) || acceptedHosts.contains(host.lowercased())`.

- [ ] **Step 1: Write the failing tests** in `ProviderPolicyTests.swift` (XCTest, a fresh
  `UserDefaults(suiteName:)` per test):
  - `testAllowedTranscriptionProvidersOnDevice`: for every `ModelProvider.allCases`,
    `isAllowed(p, allowsCloud: false)` is true exactly for
    `[.whisper, .fluidAudio, .transcribeCpp, .nativeApple, .custom]`.
  - `testAllowedAIProvidersOnDevice`: true exactly for `[.voiceInkRefine, .ollama, .custom]`.
  - `testEverythingAllowedWithCloud`: every case of both enums with `allowsCloud: true`.
  - `testLoopback`: true for `http://localhost:11434`, `http://LOCALHOST`,
    `http://127.0.0.1`, `http://127.5.5.5:8080/v1`, `http://[::1]:11434`.
  - `testLoopbackLookAlikes`: false for `http://localhost.evil.com`,
    `http://127.0.0.1.nip.io`, `http://0.0.0.0:11434`, `http://192.168.1.20:11434`,
    `http://10.0.0.5`, `https://api.openai.com`.
  - `testAcceptedHostIsCaseInsensitiveAndPortIndependent`: after `accept(host: "Server.Local")`,
    `isPermitted(URL("http://server.local:8080/v1"), allowsCloud: false)` is true and
    `isPermitted(URL("http://other.local"), allowsCloud: false)` is false.
  - `testRequirePermittedThrows`: `requirePermitted(URL("http://192.168.1.20"))` throws
    `.remoteEndpointNotConfirmed(host: "192.168.1.20")`.
- [ ] **Step 2: Implement the two files to the interfaces above.**
  - `isLoopback` lower-cases `url.host`, strips brackets, and returns true for
    `localhost`, `::1`, or an IPv4 address with four dotted numeric octets in 0–255 whose
    first octet is 127.
  - `allowsCloud` is `#if CLOUD_PROVIDERS true #else false #endif`.
  - Each switch over `ModelProvider` and `AIProvider` lists every case explicitly, with no
    `default:`, so a new upstream case fails to compile until it's classified.
- [ ] **Step 3: Container check.** Run
  `grep -c "case \." VoiceInk/Infrastructure/Privacy/ProviderPolicy.swift`. Expected: at
  least 32 (16 `ModelProvider` cases plus 16 `AIProvider` cases).
- [ ] **Step 4: Mac check (operator).**
  - In Xcode, add a macOS Unit Testing Bundle target named `ScribeInkTests` with host
    application VoiceInk. Add `Tests/ScribeInkTests/ProviderPolicyTests.swift` to it.
  - Run `xcodebuild test -project VoiceInk.xcodeproj -scheme VoiceInk -only-testing:ScribeInkTests`.
  - Expected: all seven tests pass.
- [ ] **Step 5: Commit**: `git commit -m "Add ProviderPolicy and LocalEndpoint with tests"`.

### Task 3: The build flag

**Files:**
- Create: `CloudBuild.xcconfig`
- Modify: `Makefile` (new `local-cloud` target, plus a `help` entry)
- Modify: `BUILDING.md` (a "Cloud-enabled developer build" section)

- [ ] **Step 1:** Create `CloudBuild.xcconfig` with `#include "LocalBuild.xcconfig"` and
  `SWIFT_ACTIVE_COMPILATION_CONDITIONS = $(inherited) LOCAL_BUILD CLOUD_PROVIDERS`.
- [ ] **Step 2:** Add `local-cloud`. It's the `local` recipe with
  `-xcconfig CloudBuild.xcconfig` and the app copied as `ScribeInk Cloud Dev.app`. Factor
  the shared recipe into a variable rather than duplicating it.
- [ ] **Step 3: Container check.** Run `grep -c CLOUD_PROVIDERS VoiceInk.xcodeproj/project.pbxproj`.
  Expected: `0`, meaning the default configurations never define it.
- [ ] **Step 4: Commit**: `git commit -m "Add CLOUD_PROVIDERS developer build"`.

### Task 4: Compile out the concrete cloud transcription code

**Files:**
- Create: `VoiceInk/Infrastructure/Providers/Transcription/Cloud/OpenRouterCatalogStore.swift`
  (moved verbatim from `OpenRouterProvider.swift` lines 5–48; it's local persistence only)
- Create: `VoiceInk/Features/Recording/Workflows/CustomEndpointTranscriptionService.swift`
- Modify: the 21 `EXCLUDED` files (Task 1): add the `#if CLOUD_PROVIDERS` first line and
  the `#endif` last line
- Modify: `…/Cloud/CloudProvider.swift:34-46`
- Modify: `Features/Recording/Workflows/TranscriptionServiceRegistry.swift`
- Modify: `Features/ModelLibrary/State/TranscriptionModelManager.swift:158-165`
- Modify: `VoiceInk.xcodeproj/project.pbxproj` (add the two new files)

**Interfaces:**
- Consumes: `LocalEndpoint.requirePermitted(_:)` (Task 2).
- Produces: `final class CustomEndpointTranscriptionService: TranscriptionService`. It casts
  the model to `CustomCloudModel` (else throws
  `ProviderPolicyError.providerNotAllowed(model.provider.rawValue)`), calls
  `requirePermitted` on `URL(string: model.apiEndpoint)`, then calls
  `OpenAICompatibleTranscriptionService().transcribe(audioURL:model:context:timeout: CloudTranscriptionSettings.timeout)`.

- [ ] **Step 1: Move `OpenRouterCatalogStore`** to its own file. Wrap the rest of
  `OpenRouterProvider.swift`. This departs from spec section 2 on purpose: the spec
  expected an `#if` at `AIService`'s use of `OpenRouterCatalogStore`. Because the store is
  only local `UserDefaults` persistence, moving it out of the excluded file removes that
  call site, and `AIService` needs no `#if`.
- [ ] **Step 2: Wrap the other 20 files.** In `CloudProvider.swift`, `allProviders` becomes
  `[]` in the `#else` branch.
- [ ] **Step 3: Update `TranscriptionServiceRegistry`.**
  - `cloudTranscriptionService` exists only under `#if CLOUD_PROVIDERS`.
  - A new `customEndpointTranscriptionService` is used for `.custom` in both builds.
  - In the `#else` branch, `default:` returns a `DeniedTranscriptionService` (private,
    same file) that throws `ProviderPolicyError.providerNotAllowed`. It is only a backstop
    for Task 5.
- [ ] **Step 4:** Wrap `refreshOpenRouterCatalog()`'s body in `TranscriptionModelManager`;
  on-device it returns immediately.
- [ ] **Step 5: Container check.**
  - Run: `bash scripts/check-on-device.sh; echo "exit=$?"`
  - Expected: no `FAIL: wrapped` and no `FAIL: references` lines. Exit is 0 unless Task 1's
    host list predates a moved line. If so, update only the path in the allow-list.
- [ ] **Step 6: Mac check (operator).**
  - `make local` and `make local-cloud` both build.
  - In the on-device app, a custom transcription model at `http://localhost:<port>`
    transcribes.
- [ ] **Step 7: Commit**: `git commit -m "Compile out concrete cloud transcription providers"`.

### Task 5: Enforce the policy at dispatch

**Files:**
- Modify: `Features/Recording/Workflows/TranscriptionServiceRegistry.swift`
  (`service(for:)` and `createSession`)
- Modify: `Infrastructure/Providers/Enhancement/Chat/AIChatCompletionService.swift:10-30, 68-100`
- Modify: `Features/Enhancement/State/AIService.swift` (`enhanceWithOllama`)
- Test: `Tests/ScribeInkTests/ProviderPolicyTests.swift` (add cases)

**Interfaces:**
- Consumes: `ProviderPolicy.isAllowed`, `LocalEndpoint.requirePermitted`, `ProviderPolicyError`.
- Produces: a function both dispatch points call, which throws `ProviderPolicyError`
  before any work:
  `static func ProviderPolicy.requireAllowed(_ p: ModelProvider) throws` and an overload
  for `AIProvider`.

- [ ] **Step 1: Add the failing tests.**
  - `testRequireAllowedThrowsForCloudOnDevice`: `requireAllowed(.groq)` and
    `requireAllowed(AIProvider.openAI)` throw `.providerNotAllowed` when built without
    `CLOUD_PROVIDERS`. Wrap the test body in `#if !CLOUD_PROVIDERS`.
  - `testOllamaDispatchRefusesUnconfirmedHost`: set `ollamaBaseURL` to
    `http://192.168.1.20:11434` in a test `UserDefaults`.
    `AIService.ollamaDispatchURL(defaults:)` throws
    `.remoteEndpointNotConfirmed(host: "192.168.1.20")`. With no value set, it returns
    `http://localhost:11434`.
- [ ] **Step 2: Implement.**
  - `performChatCompletion` calls `ProviderPolicy.requireAllowed(provider)` first.
  - The `.custom` branch calls `LocalEndpoint.requirePermitted(baseURL)` before
    `OpenAILLMClient.chatCompletion`.
  - Add `nonisolated static func ollamaDispatchURL(defaults: UserDefaults = .standard) throws -> URL`
    to `AIService`. It reads `ollamaBaseURL` (default `OllamaService.defaultBaseURL`),
    calls `requirePermitted`, and returns the URL. `enhanceWithOllama` calls it first.
  - The transcription dispatch calls `requireAllowed(model.provider)` in `transcribe` and
    in `createSession`. Because `createSession` doesn't throw, it returns a
    `FileTranscriptionSession` over `DeniedTranscriptionService` when the provider is
    denied.
  - Make sure `EnhancementFailureFormatter` shows `ProviderPolicyError.errorDescription`
    unchanged, and add a case if it maps errors by type.
- [ ] **Step 3: Container check.**
  - Run: `grep -n "requireAllowed\|requirePermitted" -r VoiceInk | wc -l`
  - Expected: at least 5 call sites (two in transcription, the chat entry, custom,
    Ollama).
- [ ] **Step 4: Mac check (operator).** Run the `xcodebuild test` command from Task 2.
  Expected: all tests pass.
- [ ] **Step 5: Commit**: `git commit -m "Refuse disallowed providers and unconfirmed hosts at dispatch"`.

### Task 6: Show only allowed providers

**Files:**
- Modify: `Features/Enhancement/State/AIService.swift:260-280` (`connectedProviders`)
- Modify: `Features/Onboarding/State/OnboardingCoordinator.swift:246`
- Modify: `Features/ModelLibrary/Views/APIKeyManagementView.swift:23`
- Modify: `Features/ModelLibrary/Models/TranscriptionModelRegistry.swift`
- Modify: wherever `ProviderCloudManagementView`, the API-key screens and the Local CLI
  settings are presented. Find these with `grep -rn "ProviderCloudManagementView(\|APIKeyManagementView(\|LocalCLI" VoiceInk/Features`.

- [ ] **Step 1:**
  - Add `.filter { ProviderPolicy.isAllowed($0) }` to each `AIProvider.allCases` and
    model list above, except `ModelProviderIcon.swift` (it only draws icons).
  - The predefined model list in `TranscriptionModelRegistry` keeps only models whose
    provider is allowed.
- [ ] **Step 2:** Present `ProviderCloudManagementView`, `AIProviderVerificationCard`
  (for cloud providers) and the Local CLI settings only `if ProviderPolicy.allowsCloud`.
- [ ] **Step 3: Container check.**
  - Run: `grep -rn "AIProvider.allCases" VoiceInk --include=*.swift | grep -v "ProviderPolicy\|ModelProviderIcon\|for provider in"`
  - Expected: no output.
- [ ] **Step 4: Mac check (operator).**
  - On-device build: onboarding, the model library, enhancement settings and the modes
    editor show no cloud providers and no Local CLI.
  - `make local-cloud`: they all appear.
- [ ] **Step 5: Commit**: `git commit -m "Hide cloud providers and Local CLI in on-device builds"`.

### Task 7: The blocked state

**Files:**
- Create: `VoiceInk/Infrastructure/Privacy/OnDeviceReadiness.swift`
- Modify: `Features/Recording/Presentation/RecorderUIManager.swift:224` (`toggleRecorderPanel`)
- Modify: `Features/Enhancement/Workflows/AIEnhancementService.swift` (at `enhance(` around
  line 302)
- Modify: `App/Lifecycle/` app start (the existing launch hook that calls
  `ModelPrewarmService`)

**Interfaces:**
- Produces:
  `@MainActor enum OnDeviceReadiness { static func transcriptionBlocked(_ config: TranscriptionRuntimeConfiguration?) -> Bool; static func enhancementBlocked(_ provider: AIProvider) -> Bool }`.
  Both check `ProviderPolicy.isAllowed` on the resolved per-mode value (from
  `ModeRuntimeResolver.transcriptionConfiguration`), not just the global setting.

- [ ] **Step 1: Recording.** In `toggleRecorderPanel`, before
  `SoundManager.shared.playStartSound()` in the not-visible branch, resolve the
  configuration for `modeId`. If `transcriptionBlocked`:
  - show `NotificationManager.shared.showNotification(title: String(localized: "Choose an on-device model"), type: .error)`
    (the pattern at `LastTranscriptionService.swift:130`);
  - open the model settings the same way the existing "open settings" actions do;
  - return without recording.
- [ ] **Step 2: Enhancement.** In `AIEnhancementService.enhance`, if
  `enhancementBlocked(selectedProvider)`, throw `ProviderPolicyError.providerNotAllowed`.
  Check that the existing failure path pastes the raw transcript and shows the error. If it
  doesn't, make that path paste the raw transcript.
- [ ] **Step 3: Launch.** After launch, if either check is blocked for the default mode,
  show the same notification once. Change no setting, and read no Keychain item.
- [ ] **Step 4: Container check.**
  - Run: `git diff --stat -- VoiceInk | grep -i keychain`
  - Expected: no output, meaning no Keychain code was touched.
- [ ] **Step 5: Mac check (operator).**
  - Using `defaults write <PRODUCT_BUNDLE_IDENTIFIER> <key>`, set the key
    `TranscriptionModelManager` persists the current model under (read it from
    `TranscriptionModelManager.swift`) to a Groq model's `selectionKey`. The shortcut shows
    "Choose an on-device model" and opens settings.
  - A mode with a cloud AI provider pastes the raw transcript with the notice.
- [ ] **Step 6: Commit**: `git commit -m "Block recording on disallowed models; skip disallowed enhancement"`.

### Task 8: The remote-endpoint warning

**Files:**
- Create: `VoiceInk/Features/ModelLibrary/Views/RemoteEndpointConfirmation.swift`
- Modify: `Features/ModelLibrary/Views/ProviderLocalManagementView.swift:89-99` (Ollama URL)
- Modify: `Features/ModelLibrary/Views/APIKeyManagementView.swift:151-167` (Ollama URL)
- Modify: `Features/ModelLibrary/Views/CustomProviderManagementView.swift:208` (custom
  transcription save) and `:415` (custom AI provider save)

**Interfaces:**
- Consumes: `LocalEndpoint.isLoopback`, `acceptedHosts`, `accept(host:)`.
- Produces: a SwiftUI modifier
  `.remoteEndpointConfirmation(urlString: Binding<String>, onConfirmed: () -> Void, onCancelled: () -> Void)`.
  It shows the alert, with the Global Constraints copy, only when the URL's host is
  non-loopback and not accepted. Also a view `RemoteEndpointBadge(urlString:)` that renders
  "Remote: {host}" for a non-loopback URL.

- [ ] **Step 1:** Build the modifier and badge.
  - Continue calls `accept(host:)` and then `onConfirmed`.
  - Cancel restores the previous value and calls `onCancelled`.
- [ ] **Step 2: Wire it to the four save points.**
  - `updateOllamaBaseURL` and the custom saves run only from `onConfirmed`, or directly
    when no confirmation is needed.
  - The placeholder and reset value stay `http://localhost:11434`.
- [ ] **Step 3: Container check.**
  - Run: `grep -rn "remoteEndpointConfirmation" VoiceInk | wc -l`
  - Expected: at least 5 (the definition plus four uses).
- [ ] **Step 4: Mac check (operator).** Set Ollama to `http://192.168.1.20:11434`:
  - the alert appears with the exact copy;
  - Cancel reverts;
  - Continue shows "Remote: 192.168.1.20";
  - a second host warns again.
- [ ] **Step 5: Commit**: `git commit -m "Warn before using a remote Ollama or custom endpoint"`.

### Task 9: CI, docs and final verification

**Files:**
- Create: `.github/workflows/on-device-check.yml`
- Create: `docs/qa/on-device-checklist.md` (the spec's manual QA list, verbatim)
- Modify: `CLAUDE.md` (the Non-negotiables "Nothing leaves the device" item now names
  `ProviderPolicy`, `LocalEndpoint`, `CLOUD_PROVIDERS` and the check script)

- [ ] **Step 1: The workflow.** On `pull_request` and on `push` to `main`, run
  `bash scripts/check-on-device.sh` on `ubuntu-latest`, using `actions/checkout@v4`.
- [ ] **Step 2: Final container check.**
  - Run: `bash scripts/check-on-device.sh; echo "exit=$?"`
  - Expected: `exit=0`.
- [ ] **Step 3:** Run
  `git grep -niwE "heidi|tali" -- . ':!*.xcstrings'`. Expected: no output.
- [ ] **Step 4: Commit and open the PR.** The PR body lists every "Mac check (operator)"
  step as an unchecked box, and links the QA checklist.
