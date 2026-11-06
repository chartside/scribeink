# On-device-only: manual QA on a Mac

Source: `docs/superpowers/specs/2026-11-06-on-device-only-design.md`, section 6
"Verification". The container check (`scripts/check-on-device.sh`, also run in CI) cannot
build or run the app. These steps need macOS 15+ and Xcode.

## Unit tests

- [ ] `xcodebuild test -project VoiceInk.xcodeproj -scheme VoiceInk -only-testing:VoiceInkTests`
  passes. (Amended: the tests live in the existing `VoiceInkTests` target. No new
  `ScribeInkTests` target is needed.)

## Default build (`make local`)

- [ ] The default build shows no cloud options in onboarding, the model library,
  enhancement settings or modes.
- [ ] A stale cloud transcription selection (set via `defaults write`) blocks recording
  with the "Choose an on-device model" state.
  - Amended: setting only the global current-model key does not block if the active mode
    has its own model. Test with a mode whose own transcription model is a cloud model
    (for example a Groq model). In that case the notice opens the Modes settings page.
- [ ] A stale cloud enhancement selection pastes the raw transcript with the notice.
- [ ] Setting Ollama to a LAN IP shows the warning. Cancel reverts. Continue shows
  "Remote: *host*".
  - Added: the warning appears on Connect/Refresh or Return, not on each keystroke.
- [ ] An Ollama URL edited straight in `defaults`, never confirmed, is refused at
  dispatch with "Remote endpoint not confirmed".
- [ ] Added: a custom transcription endpoint pointing at a loopback server that answers
  HTTP 307 with a remote `Location` fails. The redirect is refused.
- [ ] Added: Test Connection on an unconfirmed remote host prompts for confirmation first.

## Cloud developer build

- [ ] `make local-cloud` shows the cloud providers again.

## Network

- [ ] Optional: watch outgoing connections (Little Snitch or `nettop`) during a dictation
  with Whisper and Refine. Nothing reaches a non-local host.
