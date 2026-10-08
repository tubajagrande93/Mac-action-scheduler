# Mac Action Scheduler

A compact native macOS utility that schedules **one left mouse click** at a screen position and time chosen by the user.

**Status:** Personal-use project. The repository is currently private; the publicly downloadable and notarized installer is not yet available.

## Features

- Pick an exact point on a connected display with the full-screen crosshair overlay; press **Esc** to cancel point selection.
- Schedule for **Today**, **Tomorrow**, or a **custom date**.
- Set hours and minutes with the animated, inertial 3D wheel.
- Cancel a pending click before execution.
- Automatic macOS Light/Dark appearance; native San Francisco font; dedicated Dock/Finder icon.
- Uses native macOS `CGEvent` input events; no third-party Swift dependencies.

## Requirements

- macOS **14 or later**.
- For compiling from source: **Swift 6.3** toolchain (Swift Package Manager).
- Accessibility and permission to post synthetic mouse events, as authorized by the user in macOS System Settings.

## Build from source

From the repository root:

```bash
swift build
swift test
bash scripts/build-app.sh
```

The local packaging script creates `dist/Mac Action Scheduler.app`. To install on your own Mac, close the existing app first and run:

```bash
bash scripts/install-local-app.sh
open "$HOME/Applications/Mac Action Scheduler.app"
```

The installation script uses a **local signing identity** for developer builds. If you do not already have the expected local identity, read `scripts/setup-local-signing.sh` before using it. Self-signed local signing is **not** equivalent to Apple Developer ID distribution or notarization. This repository does not currently provide a universal public installer.

## Usage and limitations

1. Open the app and grant permissions when prompted.
2. Click **Select Point** and choose the target coordinate.
3. Choose a date and a future time.
4. Click **Schedule Click**; use the status-area cancel control if needed.

The scheduled job exists **only while the app is running**. Quitting, restarting, logging out, sleeping or locking the Mac can prevent the job from executing. The app checks for late execution and does not intentionally post a stale click. A displayed **CLICK SENT** state means macOS events were posted, **not** that the target application accepted or acted on them.

Do not rely on this app for safety-critical operations or tasks requiring guaranteed timing or delivery.

## License

**Free personal/noncommercial use only**, under the [PolyForm Strict License 1.0.0](LICENSE). This is a **source-available, non-open-source** license.

- You may use the unmodified software for noncommercial purposes, including personal projects.
- The license **does not grant permission** to sell, sublicense, redistribute, or release modified versions of the software.
- Commercial use, commercial distribution, and alternative distribution rights require separate written authorization from the copyright holder.

The full terms in [LICENSE](LICENSE) control if this summary differs. A public GitHub repository does not itself grant additional software permissions.

## Copyright and attribution

Copyright © 2026 **Nemanja Tubić (NT Studio)**. All rights reserved except as expressly licensed.

The icon and project branding are included as part of this application; no independent reuse rights are granted by the software license. macOS, Apple, and San Francisco are Apple trademarks or technologies; this app is an independent third-party project.

## Documentation included in the app

Packaged builds include copies of `README.md` and `LICENSE` inside:

```
Mac Action Scheduler.app/Contents/Resources/
```

The [LICENSE](LICENSE) applies whether the software is obtained from source or as a signed application bundle.
