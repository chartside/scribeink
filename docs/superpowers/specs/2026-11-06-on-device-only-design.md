# On-device only: design

Date: 2026-11-06. Status: approved in conversation, awaiting written-spec review.

## Goal

A default ScribeInk build sends no audio, transcript or prompt to any non-local host,
whatever is in the user's saved settings. A developer can still build a variant with the
cloud providers.

**Success means:**
- A default build can't select or reach any cloud transcription or cloud AI provider.
- The concrete cloud provider code is not compiled into it.
- Ollama and Custom endpoints reach a non-loopback host only after the user explicitly
  accepts a warning for that exact host.

**Constraints:** disable, don't delete (upstream code stays in the repo); keep upstream
merges easy; keep GPL v3.

## Roadmap context

This is sub-project 1 of 5. Each later one gets its own spec, plan and PR.

1. **On-device only** (this spec).
2. **Rename to ScribeInk:** app name, bundle ID, UI strings, icons; upstream attribution kept.
3. **Medical vocabulary and custom dictionary:** drug names, anatomy, abbreviations, used to
   bias local transcription and to correct the output.
4. **Template-driven notes:** turn a transcript into a note using `clinical-templates/` and
   a local LLM, following the rules in `clinical-templates/SCHEMA.md`.
5. **ScribeInk's own updates, licensing and announcements:** move the Sparkle feed, licence
   checks and announcements off upstream VoiceInk's services onto ScribeInk's own.

Sub-project 1 leaves updates, licensing, announcements and model downloads exactly as they
are. They carry no patient data. Sub-project 5 replaces them.

## Current state (as of upstream `5c95ff9`)

- **Transcription providers** (`ModelProvider` in
  `Features/ModelLibrary/Models/TranscriptionModel.swift`):
  - Local: Whisper, Parakeet (FluidAudio), TranscribeCpp, Native Apple.
  - Cloud: Groq, ElevenLabs, Deepgram, Mistral, Gemini, Soniox, Speechmatics, AssemblyAI,
    xAI, Cartesia, OpenRouter.
  - Custom: an OpenAI-compatible endpoint that can be local or remote.
- **AI enhancement providers** (`AIProvider` in `Features/Enhancement/State/AIService.swift`):
  - Cloud: Cerebras, Groq, Gemini, Anthropic, OpenAI, OpenRouter, Mistral, ElevenLabs,
    Deepgram, Soniox, Speechmatics, AssemblyAI.
  - Local: VoiceInk Refine (bundled model over XPC) and Ollama, which defaults to
    `http://localhost:11434`, user-editable.
  - Local CLI: runs a shell command; its presets call the cloud claude, codex and copilot CLIs.
  - Custom: an OpenAI-compatible endpoint.
- **`Infrastructure/Providers/Transcription/Cloud/`** holds 15 files plus 9 in `Streaming/`.
  - Shared, used outside the folder: `CloudProvider.swift` (`CloudProvider`,
    `CloudProviderRegistry`), `CustomModelConnectionTester.swift` and
    `OpenAICompatibleTranscriptionService.swift`.
  - Concrete providers, referenced outside the folder only at:
    - `CloudTranscriptionService`: in `TranscriptionServiceRegistry`.
    - `OpenRouterCatalogStore`: in `AIService`.
    - `OpenRouterTranscriptionCatalog`: in `TranscriptionModelManager`.
- **Build flags.** `SWIFT_ACTIVE_COMPILATION_CONDITIONS` is set per configuration in the
  project. `LocalBuild.xcconfig` adds `LOCAL_BUILD` for `make local`.
- **Tests.** There is no unit-test target, only `Tests/VoiceInkUITests`.

## Design

### 1. The build flag

- `CLOUD_PROVIDERS` is a Swift compilation condition, **absent by default**. Every normal
  build (Xcode Debug/Release, `make local`, `make release`) is on-device.
- `CloudBuild.xcconfig` adds it on top of `LocalBuild.xcconfig`. A new `make local-cloud`
  target builds with it, so developers can test the cloud variant.

### 2. Excluding the concrete cloud code

- Each of these files gets `#if CLOUD_PROVIDERS` as its first line and `#endif` as its
  last, so the compiler skips its contents entirely:
  - 12 files in `Transcription/Cloud/`, the 11 concrete providers plus their service: `AssemblyAIProvider`,
    `CartesiaProvider`, `DeepgramProvider`, `ElevenLabsProvider`, `GeminiProvider`,
    `GroqProvider`, `MistralProvider`, `OpenRouterProvider`, `SonioxProvider`,
    `SpeechmaticsProvider`, `XAIProvider` and `CloudTranscriptionService`;
  - all 9 files in `Streaming/`.
- **Stays compiled:** `CloudProvider.swift`, `CustomModelConnectionTester.swift` and
  `OpenAICompatibleTranscriptionService.swift`.
- **Registry:** `CloudProviderRegistry` returns an empty provider list when the flag is
  absent. Its references to concrete providers sit inside `#if CLOUD_PROVIDERS`.
- **Call sites:** the three outside references above get `#if CLOUD_PROVIDERS` branches.
  The on-device branch has no cloud service and no OpenRouter catalog.
- **Expect more:** the compiler will surface any reference missed here. Fix each one with
  the same pattern, and add its file to the allow-list in section 6.

### 3. `ProviderPolicy` (new: `VoiceInk/Infrastructure/Privacy/ProviderPolicy.swift`)

```swift
enum ProviderPolicy {
    static let allowsCloud: Bool  // true only under #if CLOUD_PROVIDERS
    static func isAllowed(_ provider: ModelProvider) -> Bool
    static func isAllowed(_ provider: AIProvider) -> Bool
}

enum LocalEndpoint {
    static func isLoopback(_ url: URL) -> Bool
    static func isPermitted(_ url: URL) -> Bool  // loopback, or host accepted by the user
}
```

**Allowed when `allowsCloud` is false:**
- Transcription: Whisper, Parakeet, TranscribeCpp, Native Apple, Custom.
- Enhancement: Refine, Ollama, Custom.
- Everything else, including Local CLI, is denied.
- When `allowsCloud` is true, everything is allowed, as upstream.

**What counts as loopback:**
- The host is `localhost`, any address in `127.0.0.0/8`, or `::1` (with or without
  brackets and a port).
- The check uses the parsed host, never a substring. These are not loopback:
  - `localhost.evil.com`
  - `127.0.0.1.nip.io`
  - `0.0.0.0`
  - LAN and other private addresses

**The accepted-hosts list:**
- Stored in `UserDefaults` under `acceptedRemoteHosts` as lower-cased host strings.
- Changed only by the confirmation in section 5.

### 4. Enforcement

**UI filtering:**
- Every provider picker and list filters by `isAllowed`: onboarding, the model library,
  enhancement settings and per-mode configuration.
- When `allowsCloud` is false, these are hidden: `ProviderCloudManagementView`,
  `APIKeyManagementView`'s cloud sections, `AIProviderVerificationCard` for cloud
  providers, and Local CLI settings.

**Dispatch:**
- Transcription service selection (`TranscriptionServiceRegistry`) and AI enhancement
  dispatch (`AIService`, `AIChatCompletionService`) check `isAllowed` before any work.
- For Ollama and Custom, they also check `LocalEndpoint.isPermitted` on the resolved URL.
- A refusal throws a typed `ProviderPolicyError` (`.providerNotAllowed`,
  `.remoteEndpointNotConfirmed(host:)`), never a silent fallback.

### 5. User-facing behaviour

**Blocked state:**
- At launch, and again at each dispatch, the selected transcription model and enhancement
  provider (global and per mode) are checked.
- **Disallowed transcription model:**
  - Recording is blocked.
  - The menu bar and recorder show "Choose an on-device model".
  - The recording shortcut opens the model settings instead.
- **Disallowed enhancement provider only:**
  - The recording proceeds without enhancement.
  - The local transcript is pasted with a notice that enhancement is unavailable until an
    on-device provider is chosen.
- **What it never does:** change a setting automatically, or read, send or delete a stored
  API key.
- **Clearing it:** choosing any allowed option clears the block.

**Remote-endpoint warning:**
- **When:** on saving an Ollama or Custom URL whose host is not loopback and not in
  `acceptedRemoteHosts`.
- **The prompt:** "This sends audio or transcripts containing patient information to
  *host*. Only use a server you control inside your clinic." with Cancel and Continue.
  - Cancel reverts the field.
  - Continue adds the host to the list.
- **Display:** settings show "Remote: *host*" next to a confirmed remote endpoint.
- **Defaults:** both Ollama and Custom default to localhost.

**Unchanged:** model downloads, Sparkle updates, licensing and announcements.

### 6. Verification

**`scripts/check-on-device.sh`**, a bash script that runs on Linux and macOS. It fails if
any of these is true:
1. A file on the excluded list (section 2) isn't wrapped by `#if CLOUD_PROVIDERS` on its
   first code line and `#endif` on its last.
2. A file outside `Transcription/Cloud/` names an excluded type, unless the file is on the
   script's allow-list of guarded call sites.
3. A `https://` host appears in Swift code outside an allow-list:
   - the hosts that stay (updates, licensing, announcements, model downloads, help and
     support links);
   - files already guarded by `#if CLOUD_PROVIDERS`.

**Written test-first:** the script is run against upstream `5c95ff9` first and must fail
there, then pass once the change is made.

**CI:** `.github/workflows/on-device-check.yml` runs the script on `ubuntu-latest` for
every PR and every push to `main`.

**Unit tests:**
- `Tests/ScribeInkTests/ProviderPolicyTests.swift` covers:
  - every `ModelProvider` and `AIProvider` case, allowed or denied, with and without
    `CLOUD_PROVIDERS`;
  - the loopback and look-alike list from section 3;
  - the accepted-hosts behaviour.
- **One manual step:** create the `ScribeInkTests` unit-test target in Xcode. That needs
  project-file changes better done in Xcode. The test file is ready to add.

**Manual QA on a Mac**, listed in the PR:
- [ ] The default build shows no cloud options in onboarding, the model library,
  enhancement settings or modes.
- [ ] A stale cloud transcription selection (set via `defaults write`) blocks recording
  with the "Choose an on-device model" state.
- [ ] A stale cloud enhancement selection pastes the raw transcript with the notice.
- [ ] Setting Ollama to a LAN IP shows the warning. Cancel reverts. Continue shows
  "Remote: *host*".
- [ ] An Ollama URL edited straight in `defaults`, never confirmed, is refused at
  dispatch with "Remote endpoint not confirmed".
- [ ] `make local-cloud` shows the cloud providers again.
- [ ] Optional: watch outgoing connections (Little Snitch or `nettop`) during a dictation
  with Whisper and Refine. Nothing reaches a non-local host.

## Error handling

- `ProviderPolicyError` has user-facing messages, shown through the app's existing
  enhancement-failure and recorder-error paths (`EnhancementFailureFormatter`, recorder
  notifications).
- A policy refusal is never retried and never falls back to another provider
  automatically.

## Not changed by this sub-project

- Upstream code for cloud providers: kept, only gated.
- App name, bundle ID and branding: sub-project 2.
- Updates, licensing, announcements and model download hosts: sub-project 5 for the first
  three.
- `scribeink-ios`: separate repository, separate work.

## Known limitations

- Redirects on LLMkit paths (found in the final review, 2026-11-06). Custom chat
  enhancement (`AIChatCompletionService`, through `OpenAILLMClient.chatCompletion`) and
  Ollama enhancement (`OllamaService.enhance`, through `OllamaClient.generate`) go through
  LLMkit (revision `a7541e0`). LLMkit builds its own `URLSession` per attempt
  (`performRequest` in `HTTPClient.swift`, a private ephemeral session with no delegate)
  and its public API takes no `URLSession`, configuration or delegate. So
  `PermittedRedirectGuard` cannot be attached: a 307/308 from a loopback or confirmed
  server is followed, and the POST (with the transcript) is re-sent to the `Location`
  host. Ollama's connection check and model list (`OllamaClient.checkConnection`,
  `fetchModels`, on `URLSession.shared`) follow redirects too, but send no transcript.
  The pre-dispatch `LocalEndpoint` host check still applies. The package is not forked
  or modified. Mitigation for now: point Ollama and custom chat endpoints only at servers
  you control. A fix needs either an LLMkit change that accepts a session or delegate, or
  an in-app request path for these two calls.
