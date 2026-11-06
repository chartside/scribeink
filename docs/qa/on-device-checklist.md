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
- [ ] Added: in the default build, Local CLI is absent from the enhancement provider
  settings, and a stale Local CLI selection in a mode is not used (enhancement is skipped
  with the notice).
- [ ] Setting Ollama to a LAN IP shows the warning. Cancel reverts. Continue shows
  "Remote: *host*".
  - Added: the warning appears on Connect/Refresh or Return, not on each keystroke.
- [ ] An Ollama URL edited straight in `defaults`, never confirmed, is refused at
  dispatch with "Remote endpoint not confirmed".
- [ ] Added: a custom transcription endpoint pointing at a loopback server that answers
  HTTP 307 with a remote `Location` fails. The redirect is refused.
- [ ] Added: Test Connection on an unconfirmed remote host prompts for confirmation first.
- [ ] Added: a new custom transcription model is pre-filled with
  `http://localhost:8080/v1/audio/transcriptions` and an empty model name; a new custom
  enhancement model with `http://localhost:11434/v1/chat/completions` and an empty model
  name. No cloud URL is pre-filled. (In `make local-cloud` the upstream values return.)
- [ ] Added: with a default mode whose transcription model or enhancement provider is
  disallowed, the launch notice shows once per launch. If only enhancement is blocked it
  reads "Choose an on-device AI provider"; otherwise "Choose an on-device model".
- [ ] Added: with an Ollama URL set to a LAN host never confirmed (via `defaults write`),
  launch makes no request to that host and Ollama shows as not connected.
- [ ] Added (known limitation, see the spec's "Known limitations"): a loopback custom
  chat or Ollama server answering HTTP 307 with a remote `Location` is followed, because
  LLMkit accepts no redirect guard. Confirm this is still the case and record the result;
  it is expected to fail until LLMkit or an in-app request path changes.

## Cloud developer build

- [ ] `make local-cloud` shows the cloud providers again.

## Network

- [ ] Optional: watch outgoing connections (Little Snitch or `nettop`) during a dictation
  with Whisper and Refine. Nothing reaches a non-local host.
- [ ] Added: with an OpenRouter key stored from an earlier cloud build and an empty cached
  catalog, launch the default build while watching connections (Little Snitch or
  `nettop`). Nothing reaches `openrouter.ai`.
