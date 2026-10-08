# M3 — Code Hygiene, Performance & Release Hardening (Handoff)

## Source baseline

- Repository: `https://github.com/tubajagrande93/Mac-action-scheduler`
- Starting `main` commit: `86d3d3f2ba5ae82f3c284d7930525015e1288917`
- Fallback checkpoint tag: `stable-v2` (present, untouched)
- Work branch: `refactor/m3-code-hygiene-performance`
- Toolchain: Swift 6.3.3 (`swift-driver 1.148.6`, `x86_64-apple-macosx`)
- Working tree was clean at baseline; no local changes were overwritten.

## Verified audit findings

| Priority | File | Finding | Resolution |
| --- | --- | --- | --- |
| P1 | `scripts/build-app.sh` | Packaged app built with `-c debug` | Release is now the default; `SWIFT_CONFIGURATION=debug` override retained |
| P1 | `scripts/install-local-app.sh` | `rm -rf` overwrote a possibly-running app | Deterministic running-executable preflight (exit 2) + staged copy with backup/restore |
| P1 | `WheelTimePicker.swift` | `ForEach(0..<count)` rendered 24+60 rows every frame | Bounded ±5-row rendering; visual behavior preserved |
| P2 | `AppTypography.swift` | 10 faces declared, only 3 used | Trimmed to `.regular`, `.medium`, `.semibold` |
| P2 | `ContentView.swift` | Nested redundant permission check | Simplified (`refreshSilently()` result equals `snapshot.ready`) |
| P2 | `AccessibilityPermissionService.swift` | `UserDefaults` written on every preflight | Writes only on permission-state change |
| P2 | `ChatGPTTheme.swift` | Non-English stale comment | Translated to English |
| P2 | `.gitignore` | Redundant font patterns; no secret/signing ignores | Cleaned; added `.p12/.pem/.key/.p8/.mobileprovision/.env` |

## Changes (file-by-file)

- `scripts/build-app.sh` — release by default with a validated `SWIFT_CONFIGURATION`.
- `scripts/install-local-app.sh` — running-app preflight, staged copy + validation + backup/restore (delegates the swap to `install-lib.sh`).
- `scripts/install-lib.sh` — **new** reusable swap/restore core with overridable verification/running probes.
- `scripts/test-install-local-app.sh` — **new** isolated installer failure-path tests (temp dirs only).
- `Sources/MacActionScheduler/WheelMath.swift` — **new** pure wheel math (wrap, shortest offset, momentum, visible indices).
- `Sources/MacActionScheduler/WheelTimePicker.swift` — bounded rendering + uses `WheelMath`; behavior preserved.
- `Sources/MacActionScheduler/AppTypography.swift` — removed unused faces.
- `Sources/MacActionScheduler/ContentView.swift` — removed redundant permission branch.
- `Sources/MacActionScheduler/AccessibilityPermissionService.swift` — diagnostics on state change only.
- `Sources/MacActionScheduler/ChatGPTTheme.swift` — comment clarity.
- `.gitignore` — font + secrets/signing hygiene.
- `Tests/MacActionSchedulerTests/MacActionSchedulerTests.swift` — 6 new tests.
- `README.md` — **new** public-readiness doc.

### Deliberately deferred / unchanged

- Version string (`0.2.0` / build `2`) left as-is; it corresponds to the `stable-v2`
  checkpoint and there was no tested reason to change release semantics.
- `selectedText` / `selectedUnderline` kept as separate semantic names (equivalent values).
- Scheduler timer/event posting not dependency-injected; schedule / cancel /
  execute-once still require manual end-to-end QA (no live `CGEvent`s from unit tests).
- No CADisplayLink, GPU frameworks, or external dependencies introduced.

## Performance

- Wheel: row instantiation reduced from 24/60 to ~11 per column per frame via ±5-row
  bounded rendering. Rows beyond distance ~3.45 are fully transparent in the
  original, so this is an algorithmic UI-work reduction, **not** a measured FPS claim.
- No profiler/FPS baseline was captured in this environment (no live GUI). Marked:
  **not measurable here**.

## Tests

Command: `swift test`
Result: **PASS** — 9 tests (3 pre-existing timing rules + 6 new: future threshold,
due/fresh boundaries, wheel wrap, shortest offset, momentum clamp, visible indices).
No live `CGEvent`s are posted.

Installer: `bash scripts/test-install-local-app.sh` → **PASS (15/15 assertions)**.

## Packaging verification

- `bash scripts/build-app.sh` → `dist/Mac Action Scheduler.app`
  (release, signed with stable local certificate `Mac Action Scheduler Local Code Signing`).
- `plutil -lint`: OK; `CFBundleIdentifier`: `com.ntstudio.MacActionScheduler`;
  version `0.2.0` (build `2`).
- `MacActionScheduler.icns` present and non-empty.
- `codesign --verify --deep --strict`: valid.
- Font-file scan of the bundle: empty (no bundled fonts).

## Known limitations / unverified

- Multi-monitor negative-origin layouts and sleep/wake are implemented but not
  automatically tested.
- The local self-signed signing identity is for personal use only, not a
  Developer ID / notarized distribution.
- LICENSE not chosen (unresolved public-release decision).

## Installer safety correction (follow-up)

An independent review found two installer gaps in `scripts/install-local-app.sh`,
now fixed:

1. **Restore on final-verification failure / interrupted installs.** The swap is
   driven by `scripts/install-lib.sh` with explicit `MAS_BACKED_UP` /
   `MAS_SWAPPED` / `MAS_FINALIZED` state. The backup is deleted **only after**
   the installed bundle passes final verification; on any failure (including a
   signal mid-install, handled via the `EXIT` trap) the previous app is restored,
   never deleted.
2. **Repeat the running-process check immediately before the swap.** The check now
   runs once before the build (fast-fail) and again right before the target is
   replaced, closing the build-time TOCTOU race.

The swap/restore logic was extracted into `scripts/install-lib.sh` (overridable
`mas_verify_app` / `mas_is_installed_app_running` probes) so it is testable
without real code signing or a real running app. The current code-signing
identity and the Click Engine are unchanged.

`scripts/test-install-local-app.sh` runs isolated failure-path tests entirely in
`mktemp` temporary directories (the real installed app is never touched).

## Git

- Branch: `refactor/m3-code-hygiene-performance`
- Commits:
  - `d2497d0` build: release packaging and safe install
  - `1f6b0fb` refactor: remove verified dead code and redundant checks
  - `2762161` perf: bounded wheel rendering with tests
  - `184d424` docs: build and public readiness
  - (correction commit: installer safety fixes + isolated failure-path tests)
