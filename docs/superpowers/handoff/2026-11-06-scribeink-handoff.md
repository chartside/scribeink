# ScribeInk handoff

Written 2026-11-06 for a new chat. Read this first, then `CLAUDE.md` in `chartside/scribeink`.

## What this is

ScribeInk is Chartside's GPL v3 fork of VoiceInk, a macOS dictation app, being turned into an
on-device clinical scribe. `chartside/scribeink-ios` is the iOS fork.

The operator asked to focus only on these two forks; `chartside/notes` and
`chartside/platform` are low priority. Paid tiers (support, templates, compliance, EHR
integrations) will live outside the forks, which stay open source.

**Working style the operator chose:** the superpowers skills.
- **Brainstorming:** an architectural spec first.
- **Writing plans:** an implementation plan.
- **Execution:** subagent-driven development, with a review per task, a whole-branch
  review, and one fix wave.
- **Codex reviews PRs:** comment `@codex review`, then address every finding until it
  reports none.
- **Merges:** happen only when the operator says so.

**Environment limits:**
- The cloud container has **no Swift toolchain or Xcode**. Every Swift change is checked
  by reading, by greps and by check scripts only; the operator builds and tests on a Mac.
- `whitecoatprep.com` is blocked by the session's network policy, and the operator
  declined to allow it.
- Issues are **disabled** on `chartside/scribeink`.

## Roadmap (operator's priority order)

1. **On-device only.** Done, merged in chartside/scribeink#3. Mac verification is pending:
   `docs/qa/on-device-checklist.md`.
2. **Rename to ScribeInk as a parallel install next to VoiceInk, plus the WhiteCoat Prep
   look.** In progress (see below).
3. Medical vocabulary and a custom dictionary: drug names, anatomy, abbreviations.
4. Template-driven note generation with a local LLM, using `clinical-templates/`.
5. ScribeInk's own updates, licensing and announcements, replacing the upstream services
   switched off in item 2.
6. On-device work for `scribeink-ios`. It has its own cloud clients (Deepgram, Groq,
   OpenAI-compatible), so it needs its own spec and plan; don't copy macOS changes over
   directly.

## Current state

### chartside/scribeink

- **`main`** is at `397b760` and includes on-device only (#3), the plan (#2), and the
  templates, memory and on-device spec (#1).
- **Open PR:** chartside/scribeink#4, branch `claude/focused-lamport-b8uswk`, head
  `1aa8e39`.
  - Contains the identity spec and plan, plus **PR 1 of sub-project 2 (identity, Tasks 1–5)**.
  - Fully reviewed and CI green.
  - **Waiting for the operator to say merge.** Not merged yet.
- **Next:** after #4 merges, restart the branch from `main` and run **PR 2 (the look,
  plan Tasks 6–8)** with subagent-driven development.
  - Task 6: `DESIGN.md` colour tokens as asset-catalog named colours (light and dark),
    with a WCAG AA contrast test.
  - Task 7: remap `AppTheme`, add `Typography` (New York, SF Pro, SF Mono), and move
    hard-coded colours onto tokens.
  - Task 8: restyle the shared components, with a preview catalogue.
  - Spec: `docs/superpowers/specs/2026-11-06-scribeink-identity-and-design.md`.
  - Plan: `docs/superpowers/plans/2026-11-06-scribeink-identity-and-design.md`.
- **First docs touch in PR 2:** fix `docs/qa/scribeink-identity-checklist.md` line ~18.
  The Dev-vs-Release item says models are separate, but Parakeet models are shared.

### chartside/scribeink-ios

`main` is at `0218cb1`. It has the clinical templates and `CLAUDE.md` only; no on-device
work yet.

### Other repos

- **chartside/notes:** an empty, reserved-name repo holding a copy of the templates.
  Low priority.
- **chartside/platform:** the main Chartside monorepo. The operator said to leave it alone
  for now. Its `DESIGN.md` must not change without explicit approval.

## What's in scribeink now

### On-device only (merged, #3)

- **Compile-out:** `CLOUD_PROVIDERS` is a Swift flag, absent by default. It compiles out
  the concrete cloud transcription providers. `make local-cloud` builds a developer cloud
  variant.
- **`ProviderPolicy`:** decides what's allowed on-device.
  - Transcription: Whisper, Parakeet, TranscribeCpp, Apple and Custom.
  - Enhancement: Refine, Ollama and Custom.
  - Local CLI and every cloud provider are refused at dispatch and hidden in the UI.
- **`LocalEndpoint`:** loopback hosts, plus hosts the user explicitly accepted after a
  patient-data warning (stored in `acceptedRemoteHosts`).
- **`PermittedRedirectGuard`:** guards the custom transcription upload and its Test
  Connection only.
- **Blocked state:** "Choose an on-device model" for stale cloud settings. It opens Modes
  or Models settings, and never changes settings automatically.
- **Checks:** `scripts/check-on-device.sh` plus `scripts/on-device-hosts.allow`, run by
  the CI workflow `.github/workflows/on-device-check.yml`.
- **Known gap:** custom chat enhancement and Ollama go through the LLMkit package, which
  builds its own `URLSession` with no redirect guard. A 307/308 from a permitted server
  re-sends the transcript to the redirect target. This is documented in the on-device
  spec's "Known limitations" and in `CLAUDE.md`.

### Identity (PR 1, in #4, not merged)

- **Bundle IDs:** `com.chartside.ScribeInk`, `.dev`, `.RefineXPC`, `com.chartside.ScribeInkTests`
  and `com.chartside.ScribeInkUITests`.
- **Products:** `ScribeInk.app` / `ScribeInk Dev.app`. `PRODUCT_MODULE_NAME` stays
  `VoiceInk`.
- **Separate stores:** Keychain group `$(AppIdentifierPrefix)com.chartside.ScribeInk`;
  iCloud container `iCloud.com.chartside.ScribeInk`.
- **`AppIdentity`** is the only source of IDs and paths: Application Support folder,
  Keychain services, logger subsystem and queue labels.
- **Internal names stay `VoiceInk*`:** Xcode targets, files and Swift types keep upstream
  names, so upstream merges stay workable.
- **Rename:** user-facing strings say ScribeInk in all locales. The Refine model shows as
  "ScribeInk Refine", while its stored raw value stays "VoiceInk Refine". Onboarding has a
  shortcut hint for people who also run VoiceInk.
- **`UpstreamServices`:** everything off with the code kept.
  - Sparkle updater never starts; feed and key removed from `Info.plist`.
  - Licensing behaves as licensed, with no Polar calls.
  - No announcements and no star prompt.
  - Support URL: `https://github.com/chartside/scribeink`.
- **About panel:** "ScribeInk is based on VoiceInk by Prakash Joshi Pax, licensed under
  GPL v3", plus "Updates are not available yet."
- **Placeholder "SI" icons:** from `scripts/generate-placeholder-icons.py`.
- **Checks:** `scripts/check-scribeink-identity.sh` plus `scripts/scribeink-identity.allow`,
  blocking in CI.

### Docs

- `CLAUDE.md`: project memory and non-negotiables.
- `DESIGN.md`: the WhiteCoat Prep design system, sampled from screenshots.
  - Colours: teal `#1A6B5A`, ink `#1D1D1F`, canvas `#FAFAF8`, hairline `#E7E6E1`,
    tint `#E9F5F1`, logo tile `#101F26`, dot `#E45630` (logo only).
  - Dark-mode values are a proposal.
- `clinical-templates/`: 8 templates plus a self-contained `SCHEMA.md`, with no
  third-party product names.
- `docs/qa/*.md`: Mac checklists.
- `docs/superpowers/specs|plans/`.

## Non-negotiables (from CLAUDE.md)

- Nothing leaves the device. Treat any new network call as a bug unless the operator
  approves it.
- No PHI in the repo; synthetic data only.
- Never invent clinical content. A note holds only what was said.
- Keep GPL v3 and upstream attribution.
- Mac only for now.
- **No competitor product names** in code, templates, docs or commit messages. That
  includes the scribe products the templates were derived from.
- Disable, don't delete, upstream code.

## Decisions already made (don't re-ask)

- **Parallel install, clean start:** no migration from VoiceInk.
- **Updater off** until roadmap item 5.
- **Licensing, announcements, star prompt and upstream support links:** off with the code
  kept; roadmap item 5 replaces them.
- **Fonts:** macOS system fonts only (New York, SF Pro, SF Mono).
- **Icons:** generated placeholders until final artwork exists.
- **Delivery:** one spec, two PRs (identity, then look).
- **Ollama and Custom endpoints:** default to localhost, with a warning before a remote
  host.
- **Default build behaviour:** in default builds, saved cloud settings block recording
  instead of falling back.

## Rulings made during execution (operator may revisit)

- **PR 1 checkpoint:** an extra review was run before stopping for the merge.
- **Debug product name:** `"ScribeInk Dev"`. Test hosts point at the new product names.
- **No default shortcut exists upstream:** onboarding shows a hint instead of a different
  default (departs from the spec).
- **XPC service name:** the constant `com.chartside.ScribeInk.RefineXPC`. The embedded
  service is app-scoped, so the spec's "derived from the bundle ID" wasn't needed.
- **Refine:** a display-name mapping; the stored raw value is unchanged.
- **`InfoPlist.xcstrings`:** `CFBundleDisplayName` and `CFBundleName` were removed, so
  the per-configuration build settings win.
- **About:** uses the standard macOS About panel, since there was no custom About view.
- **Parakeet (FluidAudio) model cache:** stays shared with VoiceInk, documented. The code
  move is a follow-up.
- **`make local-cloud`:** keeps the same bundle ID as `make local` and shares its data.
  BUILDING.md warns never to run it on a machine with patient data. A separate ID is a
  follow-up.
- **`scripts/release.sh`:** the expected bundle ID is updated. Its appcast check is still
  upstream's (roadmap item 5).
- **LLMkit redirect gap:** documented, not fixed; the package has no session injection.

## Follow-ups to schedule

- **LLMkit redirect gap.** Below is the issue to file once Issues are enabled on
  `chartside/scribeink` (Settings → General → Features → Issues).
- **`make local-cloud`:** give it its own bundle ID. It needs care: the RefineXPC target
  and the constant service name.
- **Parakeet cache:** move it into `AppIdentity.applicationSupportFolderName`. The unified
  streaming managers use the library default today, and users need one re-download.
- **Refine XPC errors:** strings in the client and service still say "VoiceInk Refine".
- **iCloud dictionary sync:** decide before a signed Release build. Vocabulary can contain
  patient names, and sync sends it to Apple's iCloud.
- **Signing:** signed builds need Chartside's Apple developer team. `DEVELOPMENT_TEAM` is
  still upstream's `V6J6A3VWY2`; `make local` is unaffected.
- **Missing translations:** "ScribeInk Refine" and the onboarding hint.
- **Mac verification:** run both QA checklists on a Mac, including the parallel install
  with VoiceInk and `nettop` showing no upstream traffic.

### Issue text: LLMkit chat and Ollama requests follow redirects without the on-device host check

> **Open risk.** Custom chat and Ollama requests go through the external LLMkit package.
> It creates its own network connection with no redirect check, so a server you approved
> that answers with a redirect would re-send the transcript to wherever it points. This
> is documented as a known limitation. Closing it means changing LLMkit, or forking it, so
> the app can supply its own connection.
>
> **Details.**
> - **What follows the redirect:** at the pinned LLMkit revision `a7541e0`
>   (`Package.resolved`), `OpenAILLMClient.chatCompletion` and `OllamaClient.generate`
>   take no `URLSession`, configuration or delegate parameter. `HTTPClient.swift` builds a
>   private ephemeral `URLSession(configuration:)` with no delegate.
>   `checkConnection`/`fetchModels` use `URLSession.shared`.
> - **Effect:** on an HTTP 307/308 from a loopback or user-accepted server, `URLSession`
>   re-POSTs the transcript and system prompt to the `Location` host without the
>   `LocalEndpoint` check.
> - **Also affected, with no patient data:** custom enhancement Test Connection can follow
>   a redirect carrying the API key.
> - **Already guarded:** the custom transcription upload and its Test Connection use
>   `PermittedRedirectGuard`.
> - **Likelihood:** low. It needs a misbehaving server the user runs or explicitly
>   accepted.
>
> **Options.**
> 1. Change LLMkit upstream to accept an injected `URLSession` or `URLSessionTaskDelegate`.
> 2. Fork LLMkit under `chartside` and add the injection there.
> 3. Send OpenAI-compatible and Ollama chat from an app-side `URLSession` that uses
>    `PermittedRedirectGuard`.
>
> Then remove the "Known limitations" entry from the spec and `CLAUDE.md`, and add a Mac QA
> step: a loopback server that answers 307 to a remote host must be refused on chat and
> Ollama.

## How to resume in a new chat

1. **Attach repos.** Attach `chartside/scribeink`, and `chartside/scribeink-ios` if needed.
   Read `CLAUDE.md`.
2. **PR #4.** Check chartside/scribeink#4. If the operator approves, merge it (squash).
3. **Restart the branch from `main`:**
   ```bash
   git fetch origin main && git checkout -B claude/<branch> origin/main
   ```
4. **Run PR 2.** Use the superpowers `subagent-driven-development` skill on
   `docs/superpowers/plans/2026-11-06-scribeink-identity-and-design.md`, Tasks 6–8 only.
   - Create a fresh workspace and ledger; the previous session's ledger was in git-ignored
     scratch and is gone.
   - Fold in the checklist line fix.
5. **Open PR 2.** Ask Codex to review, address its findings, and merge only when the
   operator says so.
6. **Then roadmap item 3 (medical vocabulary).** Start with the superpowers
   `brainstorming` skill.
