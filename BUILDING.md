# Building ScribeInk

## Requirements

- macOS 15.0 or later
- Xcode with Command Line Tools
- Git

## Local Build

```bash
git clone https://github.com/chartside/scribeink.git
cd scribeink
make local
open ~/Downloads/ScribeInk.app
```

`make local` prepares `whisper.xcframework` in `~/VoiceInk-Dependencies`, builds Release in `.local-build`, and copies `ScribeInk.app` to `~/Downloads`.

It uses `LocalBuild.xcconfig`, `VoiceInk.local.entitlements`, and the `LOCAL_BUILD` Swift flag. Without an override, it uses the only available Apple Development identity or falls back to ad-hoc signing when none or multiple are found.

Choose an identity explicitly:

```bash
make local LOCAL_CODESIGN_IDENTITY="<SHA or name>"
```

Force ad-hoc signing:

```bash
make local LOCAL_CODESIGN_IDENTITY=-
```

Local builds do not include iCloud dictionary sync or automatic updates. Ad-hoc builds may require macOS permissions again after rebuilding.

## Cloud-enabled developer build

Default builds are on-device only. For development, `make local-cloud` builds with the `CLOUD_PROVIDERS` Swift flag (`CloudBuild.xcconfig`, which includes `LocalBuild.xcconfig`) and copies the app as `~/Downloads/ScribeInk Cloud Dev.app`. It accepts the same `LOCAL_CODESIGN_IDENTITY` override as `make local`.

```bash
make local-cloud
```

**Warning:** this build uses the same bundle identifier as `make local`, so it shares all data with it (history, recordings, modes, settings and Keychain items) and allows cloud providers. Never run it on a machine that holds patient data, and never distribute it. The flag is not defined in any Xcode configuration, so `make local`, `make build`, `make dev` and `make release` never enable it.

## Other Commands

- `make check` — verify required tools
- `make whisper` — prepare `whisper.xcframework`
- `make build` — build the standard Debug configuration
- `make dev` — build and launch `ScribeInk Dev.app`
- `make run` — launch `~/Downloads/ScribeInk.app`, or the first app found in DerivedData
- `make release` — create the signed release package
- `make release-setup` — configure release notarization credentials
- `make clean` — remove `~/VoiceInk-Dependencies`
- `make help` — list all commands

## Build with Xcode

```bash
make setup
open VoiceInk.xcodeproj
```

Select the `VoiceInk` scheme (Xcode target and scheme names stay `VoiceInk`). Run builds `ScribeInk Dev.app`; Archive builds `ScribeInk.app` (Release). `LOCAL_BUILD` applies only through `make local`.

## Troubleshooting

- Run `make check` to verify the required tools.
- Run `make whisper` if the framework is missing.
- If several Apple Development identities exist, set `LOCAL_CODESIGN_IDENTITY` explicitly.
- For additional help, open a [GitHub issue](https://github.com/chartside/scribeink/issues).
