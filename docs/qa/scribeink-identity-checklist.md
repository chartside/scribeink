# ScribeInk identity: Mac QA checklist

Spec: `docs/superpowers/specs/2026-11-06-scribeink-identity-and-design.md`. Needs a Mac (macOS 15+,
Xcode); none of this can be checked in a Linux container.

Prerequisite for signed builds: `DEVELOPMENT_TEAM` is still upstream's. Signed and notarized
builds need Chartside's Apple team set first. `make local` builds work without it.

## On a Mac

- [ ] **Parallel install:** with both apps installed and running, each keeps its own settings, history, Whisper/TranscribeCpp/Refine models and Keychain. Parakeet model files are the exception: they are shared with VoiceInk, so deleting one in either app removes it for both. Each shortcut triggers only its own app, and launch at login is independent.
- [ ] **No upstream services:** "Check for updates" is gone, no licence or trial prompt appears, and no traffic goes to `tryvoiceink.com`, `polar.sh` or `beingpax.github.io` (watched with `nettop` or Little Snitch).
- [ ] **About:** shows the attribution.
- [ ] **Visual pass:** dashboard, settings, recorder and onboarding, in light and dark.

## Also check

- [ ] Dev and Release installed together stay separate (`ScribeInk Dev`, `com.chartside.ScribeInk.dev`, and `ScribeInk`, `com.chartside.ScribeInk`): own settings, history, models, Keychain and log subsystem.
- [ ] Onboarding shows the shortcut hint.
- [ ] The About panel (ScribeInk menu > About ScribeInk) shows the attribution "ScribeInk is based on VoiceInk by Prakash Joshi Pax, licensed under GPL v3" (linking to github.com/Beingpax/VoiceInk), "Updates are not available yet." and the support link github.com/chartside/scribeink. It reads in light and dark.
- [ ] `make local` produces `~/Downloads/ScribeInk.app`, and its data lands in `~/Library/Application Support/com.chartside.ScribeInk`.
- [ ] Settings > General shows "Updates are not available yet." and no update controls.
- [ ] The placeholder app icon and menu-bar glyph show (menu-bar glyph tints correctly in light and dark).
