# Mac Action Scheduler

A compact native macOS utility that schedules **one** native left click at a
screen coordinate you pick, then executes it exactly once.

## What it does

- Lets you pick a target point on any connected display (full-screen overlay
  with a precision cursor; `Esc` cancels).
- Schedules the click for today, tomorrow, or a custom date, at a chosen hour
  and minute using an animated inertial time wheel.
- Sends a single `leftMouseDown` + `leftMouseUp` `CGEvent` pair at the target.
- Requires and verifies both Accessibility and synthetic-event permissions
  before scheduling or firing.
- Ships as a fixed 360 × 450 pt window with automatic Light / Dark support.

## What it does NOT do

- It does **not** survive quitting the app, rebooting, or logging out — the job
  lives only in the running process.
- It does **not** wake or unlock a sleeping/locked Mac; a fire that arrives
  more than ~3 seconds late is reported as `MISSED (MAC WAS ASLEEP)`.
- It does **not** bypass macOS privacy protections (TCC). Permissions must be
  granted by the user in System Settings.
- It does **not** guarantee the receiving app reacts to the click; `CLICK SENT`
  means the events were posted, not that the target acted on them.

## Requirements

- macOS 14 or later.
- A Swift 6.3 toolchain (the package declares `swift-tools-version: 6.3` and
  Swift 6 language mode with strict concurrency).
- No bundled fonts or third-party dependencies: the UI uses the installed
  San Francisco system font.

## Build & test

```bash
cd "/path/to/Mac Action Scheduler"
swift build
swift test
swift build -c release --product MacActionScheduler
```

## Package and install (advanced)

`scripts/build-app.sh` builds a release `.app` bundle at
`dist/Mac Action Scheduler.app` (override with `SWIFT_CONFIGURATION=debug` for
development). `scripts/install-local-app.sh` copies it to `~/Applications`,
but only after verifying it is signed with your stable local certificate — and
it **refuses to overwrite the app while it is running**, so an active scheduled
job is never destroyed.

```bash
bash scripts/build-app.sh          # create the .app (does not install)
bash scripts/install-local-app.sh  # install to ~/Applications
```

A stable local code-signing identity is required so macOS keeps recognizing
the app for Accessibility after rebuilds. Create it once with
`bash scripts/setup-local-signing.sh` (this generates a self-signed,
code-signing-only identity in your login Keychain; the private key is never
committed).

## Permissions

The app checks two related authorizations separately so it can fail precisely:

- **Accessibility** (`AXIsProcessTrusted`) — general assistive-access trust.
- **Synthetic events** (`CGPreflightPostEventAccess`) — permission to post
  input events to the HID event tap.

Grant both in **System Settings → Privacy & Security → Accessibility**. The app
never covers the system's permission dialog with its own window.

## Unverified scenarios

- Multi-monitor layouts with negative-origin coordinates are implemented but
  not covered by automated tests; verify manually.
- Sleep/wake and rapid permission revocation are guarded but not automatically
  tested.

## Distribution note

The local signing identity used here is a personal self-signed certificate,
suitable for a developer's own machine, **not** a public Developer ID /
notarized distribution. A public repository does not make the built `.app`
universally trusted on other Macs.

## License

No license has been chosen yet — this is an unresolved public-release decision
and will be added once the author selects one.
