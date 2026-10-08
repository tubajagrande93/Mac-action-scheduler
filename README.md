# Mac Action Scheduler

A compact native macOS utility that schedules **one left mouse click** at a screen position and time chosen by the user.

**[Download v0.2.0 — Universal macOS DMG](https://github.com/tubajagrande93/Mac-action-scheduler/releases/download/v0.2.0/Mac-Action-Scheduler-0.2.0-macOS-universal.dmg)** · [Release notes](https://github.com/tubajagrande93/Mac-action-scheduler/releases/tag/v0.2.0)

**Compatibility:** macOS 14+, Intel (`x86_64`) and Apple Silicon (`arm64`). Free for permitted noncommercial uses; this release is not Apple notarized.

**SHA-256:** `ca62122f4fb5c06fe6fb99911763dcb041b217e694f5c40f83c6da4c6587be7a`

**Status:** Free for noncommercial use and sharing under the license below. Builds made from this repository are not Apple Developer ID notarized.

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

The installation script uses a **local signing identity** for developer builds. If you do not already have the expected local identity, read `scripts/setup-local-signing.sh` before using it. This local identity is **not** an Apple Developer ID certificate.

## Free distribution (Intel + Apple Silicon)

On a Mac with the Swift 6.3 toolchain and Xcode command-line tools, build a Universal macOS package:

```bash
swift test
MAS_UNIVERSAL=1 bash scripts/build-app.sh
bash scripts/create-dmg.sh
```

The resulting `dist/Mac-Action-Scheduler-0.2.0-macOS-universal.dmg` contains the app, a drag-to-Applications shortcut, `INSTALL.txt`, README and LICENSE. The script prints a SHA-256 checksum. The usual `bash scripts/build-app.sh` remains a native-architecture local build.

```bash
lipo -archs "dist/Mac Action Scheduler.app/Contents/MacOS/MacActionScheduler"
```

A Universal build must report both `arm64` and `x86_64`. The Intel slice can be tested on an Intel Mac; the Apple Silicon slice requires testing on an Apple Silicon Mac.

### First launch on another Mac

The free package is **not Apple-notarized** and does not use an Apple Developer ID certificate. macOS Gatekeeper may prevent the first launch. If you trust the origin and have verified the download, try opening the app, then use **System Settings → Privacy & Security → Open Anyway** if offered. Never disable Gatekeeper system-wide. Grant the requested Accessibility and synthetic click permissions only if you understand what the app does.

For official guidance see [Apple: Safely open apps on your Mac](https://support.apple.com/102445).

The official download is available from [GitHub Releases](https://github.com/tubajagrande93/Mac-action-scheduler/releases/tag/v0.2.0). Verify the downloaded DMG against the SHA-256 hash above. The license and README are also included in the package.

## Usage and limitations

1. Open the app and grant permissions when prompted.
2. Click **Select Point** and choose the target coordinate.
3. Choose a date and a future time.
4. Click **Schedule Click**; use the status-area cancel control if needed.

The scheduled job exists **only while the app is running**. Quitting, restarting, logging out, sleeping or locking the Mac can prevent the job from executing. The app checks for late execution and does not intentionally post a stale click. A displayed **CLICK SENT** state means macOS events were posted, **not** that the target application accepted or acted on them.

Do not rely on this app for safety-critical operations or tasks requiring guaranteed timing or delivery.

## License

**Free noncommercial use and free sharing**, under the [PolyForm Noncommercial License 1.0.0](LICENSE). This is a **source-available, non-OSI-open-source** license.

- You may download and use the software for personal and other purposes permitted by the license, without paying a license fee.
- You may **share copies for free** and redistribute the software for noncommercial purposes, provided you include the license terms (or their URL) and required copyright notices.
- You may modify and redistribute modified versions for noncommercial purposes, following the license conditions.
- **Selling the software or distributing it commercially is not authorized.** Commercial use requires separate permission from the copyright holder.

The full terms in [LICENSE](LICENSE) control if this summary differs. Publishing the repository does not waive the copyright owner's rights.

## Copyright and attribution

Copyright © 2026 **Nemanja Tubić ([NT Studio](https://ntstudio.hr))**. All rights reserved except as expressly licensed.

The application icon can accompany copies and modified versions redistributed under the software license; unrelated use of the project's name or branding is not separately authorized. macOS, Apple, and San Francisco are Apple trademarks or technologies; this app is an independent third-party project.

## Documentation included in the app

Packaged builds include copies of `README.md` and `LICENSE` inside:

```
Mac Action Scheduler.app/Contents/Resources/
```

The [LICENSE](LICENSE) applies whether the software is obtained from source or as a signed application bundle.
