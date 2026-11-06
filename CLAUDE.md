# ScribeInk (macOS): project memory

ScribeInk is Chartside's fork of [VoiceInk](https://github.com/Beingpax/VoiceInk) (GPL v3),
being turned into an on-device clinical scribe for clinicians. The fork stays open source
under GPL v3. Chartside's paid tiers (support, templates, compliance, EHR integrations) live
outside this repo. This repo is self-contained: it depends on no other Chartside repository,
and nothing here should be copied from or synced with one.

## Non-negotiables

1. **Nothing leaves the device.** No audio, transcript, note or prompt goes to a network
   service. Transcription (whisper.cpp / Parakeet) and note generation run locally.
   VoiceInk's cloud transcription providers (`Infrastructure/Providers/Transcription/Cloud/`)
   are compiled only under the `CLOUD_PROVIDERS` flag, which the default build leaves off
   (`make local-cloud` turns it on for development). The cloud enhancement/chat providers
   stay compiled but are hidden in the UI and refused by `ProviderPolicy` at dispatch.
   Transcription and enhancement dispatch check `ProviderPolicy`; background work that
   would reach a disallowed provider (the OpenRouter catalog fetch, API key verification)
   is skipped. Custom and Ollama endpoints are checked against `LocalEndpoint` (remote
   hosts need confirmation). `PermittedRedirectGuard` (refuses redirects off the permitted
   host) covers only the custom transcription upload and its connection test. Known gap:
   custom chat enhancement and Ollama go through LLMkit, whose request API takes no
   `URLSession` or delegate, so a 307/308 from a permitted server is followed and the
   request (with the transcript) is re-sent to the redirect host. Only point these at
   servers you control; see the spec's "Known limitations". `scripts/check-on-device.sh`
   enforces the cloud transcription gating and the network host allowlist, and CI runs it
   on every PR. Treat any new network call as a bug unless the operator approves it.
2. **No PHI in the repo.** Tests, fixtures, screenshots and logs use synthetic data only.
3. **Never invent clinical content.** A note holds only what was said. See the template
   rules in `clinical-templates/README.md`.
4. **Keep GPL v3.** Keep upstream copyright notices. Only add code we can license under GPL.
5. **Mac-only for now.**
6. **No competitor product names** in code, templates, docs or commit messages.

## Clinical note templates

`clinical-templates/` holds the starting template set, in the format described in
`clinical-templates/SCHEMA.md`. This directory is the source of truth for the app's
templates. They aren't connected to the app yet. The plan is to use them as the prompt for
VoiceInk's local "enhancement" step (`Core/Enhancement/`).

The set: SOAP (single issue), SOAP by issue, internal medicine new patient (with patient
summary), cardiology SOAP, cardiology letter to referrer, psychiatric consultation,
comprehensive geriatric assessment, emergency note. The README has the backlog of templates
still to build.

## Roadmap (agreed 2026-11-06)

- Remove or disable the cloud transcription and LLM paths so the app works fully offline.
  Implemented: cloud transcription gated behind `CLOUD_PROVIDERS`; cloud enhancement
  refused by `ProviderPolicy` and hidden; pending verification on a Mac
  (`docs/qa/on-device-checklist.md`).
Priority order set by the operator on 2026-11-06:

1. Rename to ScribeInk as a parallel install next to VoiceInk, and apply `DESIGN.md`
   (spec: `docs/superpowers/specs/2026-11-06-scribeink-identity-and-design.md`). Internal
   Xcode target, file and Swift type names stay `VoiceInk*` to keep upstream merges
   workable; only user-visible names change.
2. Medical vocabulary and a custom dictionary (drug names, anatomy, abbreviations).
3. Template-driven note generation from the transcript, using a local LLM.
4. ScribeInk's own updates, licensing and announcements (replacing the upstream services
   switched off in item 1).
5. `scribeink-ios` on-device work.

## Design

Read `DESIGN.md` before any visual or UI change. It holds the colour tokens, type roles,
component shapes and voice shared with WhiteCoat Prep. Don't introduce colours or fonts
outside it without the operator's approval. Until sub-project 2, existing `AppTheme` tokens
are fine.

## Build

See `BUILDING.md` (`make local`). It needs macOS 15+ and Xcode, so it can't be built in a
Linux container.
