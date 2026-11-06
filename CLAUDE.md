# ScribeInk (macOS): project memory

ScribeInk is Chartside's fork of [VoiceInk](https://github.com/Beingpax/VoiceInk) (GPL v3),
being turned into an on-device clinical scribe for clinicians. The fork stays open source
under GPL v3. Chartside's paid tiers (support, templates, compliance, EHR integrations) live
outside this repo. This repo is self-contained: it depends on no other Chartside repository,
and nothing here should be copied from or synced with one.

## Non-negotiables

1. **Nothing leaves the device.** No audio, transcript, note or prompt goes to a network
   service. Transcription (whisper.cpp / Parakeet) and note generation run locally.
   VoiceInk's cloud providers (`Infrastructure/Providers/Transcription/Cloud/`, the cloud
   chat/enhancement providers) are to be removed or hard-disabled, not just hidden. Treat
   any new network call as a bug unless the operator approves it.
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
- Medical vocabulary and a custom dictionary (drug names, anatomy, abbreviations).
- Template-driven note generation from the transcript, using a local LLM.
- Rename from VoiceInk to ScribeInk in the UI, bundle ID and app name (keep upstream attribution).

## Build

See `BUILDING.md` (`make local`). It needs macOS 15+ and Xcode, so it can't be built in a
Linux container.
