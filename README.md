# OpenLid

**A little more alive.** An independent, open-source macOS menu-bar app that folds your desktop as you close your MacBook lid.

Native Swift + SwiftUI, ScreenCaptureKit, and Metal-backed Core Image. No dependencies, accounts, telemetry, or subscriptions. MIT licensed.

> **Local alpha, not a validated release.** The native preview and automated checks can be tested without permissions. Physical lid behavior and the live capture pipeline still require testing on supported hardware before release. This is an original implementation inspired by [Bendy](https://trybendy.app/); no Bendy code, branding, or assets are included.

## Build and run

The [OpenLid website](https://ameeetgaikwad.github.io/OpenLid/) includes an interactive, illustrative preview of the three styles. A notarized download is not available yet.

Requires macOS 14+ and Swift 5.9+ (Xcode or Apple's Command Line Tools). The live effect requires a built-in display and an accessible Apple lid angle HID sensor. Not every Apple silicon MacBook exposes that sensor.

```sh
git clone https://github.com/ameeetgaikwad/OpenLid.git
cd OpenLid
bash scripts/build-app.sh
open dist/OpenLid.app
```

The script creates an ad-hoc signed app for the current architecture. It uses workspace-local compiler caches and does not need an Apple developer account. `--disable-sandbox` affects SwiftPM's manifest subprocess only; it does not change macOS security settings. There are no remote package dependencies.

For everyday use, copy the built app to a stable location such as Applications before granting Screen Recording permission. Rebuilding an ad-hoc signed app can invalidate macOS's previous permission grant.

To package a local development DMG, run `bash scripts/build-dmg.sh`. It creates a host-architecture image and SHA-256 checksum in `dist/`, containing OpenLid and an Applications shortcut. This artifact is ad-hoc signed and not notarized; public binary distribution remains pending validation.

## Try it

1. Open the app. **Appearance** contains a manual preview that needs no screen access.
2. Drag **Preview lid angle**, choose **Paper**, **Dusk**, or **Mist**, and tune perspective, softness, and shadow.
3. In **General**, check sensor availability and set the angle above which the effect clears.
4. To use the real desktop, click **Enable live effect**. Grant OpenLid Screen Recording access through macOS if requested, then relaunch and enable again.
5. Gently lower the lid while keeping it open. The effect targets only the built-in display. Use the menu-bar laptop icon to pause.

The three styles retain distinct effects: Paper uses light shading and subtle blur, Dusk emphasizes deeper shading, and Mist emphasizes blur. Softness and Shadow control those effects; there is no forced blackout shared by all styles.

**Permission helper:** General → Open permission helper & Settings opens a floating helper beside System Settings. Drag its OpenLid.app card into the permission list where supported, or use **Show OpenLid in Finder** and System Settings' **+** button. If OpenLid is already listed, switch it on. **Check permission** only reads permission state; it does not start capture. The helper stays visible when System Settings is focused and can be closed with Done. If macOS shows access enabled but the helper still reports missing access, quit and reopen OpenLid so macOS can refresh the process permission state.

The live effect is **paused on every launch**. Closing the settings window leaves the menu-bar app running. Escape pauses while OpenLid has keyboard focus; the menu-bar pause is the control to use from other apps. No global keyboard monitoring permission is requested.

## Safety and current limits

- Pause, sleep, screen lock, session changes, display reconfiguration, sensor failure, and capture failure hide the overlay and stop capture. Enable again manually afterward.
- Continuous folding has a 15-second safety timeout so the desktop cannot stay obscured indefinitely. The overlay ignores mouse input; the real menu bar remains above it.
- Capture is limited to 30 fps and at most 1920 pixels wide, with three queued frames. Retina sharpness, HDR, GPU power use, and fast lid motion still need measurement.
- The current sensor implementation polls feature report 1 at 30 Hz while enabled. It does not reproduce Bendy's advertised event-driven sensor implementation. Discovery also reads one report on startup or recheck.
- Unsupported models get an explicit message and can still use preview. We do not request root privileges or use synthetic sensor data.
- Manual preview uses generated artwork and a SwiftUI 3D transform; the live desktop uses Core Image perspective projection. Preview is illustrative, not a pixel-exact simulator of screen capture.
- No startup-at-login, sounds, auto-update, external-display effects, or notarized download is shipped yet.
- This does not stop normal lid-close sleep and is not a clamshell utility.

## Developer checks

```sh
bash scripts/test.sh
bash scripts/build-app.sh
dist/OpenLid.app/Contents/MacOS/OpenLid --diagnostics
dist/OpenLid.app/Contents/MacOS/OpenLid --render-check
```

Diagnostics print `lid_angle_degrees: <value>` or `unsupported: <reason>`, permission state, and the macOS version. Diagnostics do not start capture or request permission. Please do not interpret a sensor read or a passing build as evidence that the live effect has been validated.

`--render-check` exercises the production Core Image filter graph on the Metal GPU with generated pixels. It never captures a screen. Restricted shells may deny GPU/HID access and report them as unavailable; run these diagnostics from a normal local terminal to establish hardware support. The core suite is a small assertion executable so Apple's Command Line Tools work without XCTest/full Xcode.

See [CONTRIBUTING.md](CONTRIBUTING.md), [architecture](docs/architecture.md), and the [manual validation checklist](docs/manual-validation.md).

For the full automated contributor/CI check, run `bash scripts/check.sh`. Hardware and permission checks remain separate.

## Contributing and project status

Contributions and hardware compatibility reports are welcome. Start with the [contribution guide](CONTRIBUTING.md) and [roadmap](ROADMAP.md). Use the [GitHub issue forms](https://github.com/ameeetgaikwad/OpenLid/issues/new/choose) for bugs and feature requests.

- [Changelog](CHANGELOG.md): unreleased changes and validation limits.
- [Security](SECURITY.md): private reporting guidance.
- [Code of Conduct](CODE_OF_CONDUCT.md): community expectations.
- [Launch and release checklist](docs/releasing.md): maintainer setup and binary distribution requirements.
- [MIT license](LICENSE): use, modify, and distribute under its terms.

## Privacy

Frames stay in process memory and feed a local GPU render. The app writes no captured images or audio, opens no network connections, and has no analytics or crash-reporting SDK. Only effect preferences are persisted via UserDefaults. ScreenCaptureKit excludes the OpenLid application to prevent recursive capture. See [PRIVACY.md](PRIVACY.md).

## References and credit

- [Bendy](https://trybendy.app/) — product inspiration; an independent commercial app.
- [Sam Gold's LidAngleSensor](https://github.com/samhenrigold/LidAngleSensor) — public discovery of the MacBook lid sensor and hardware caveats.
- [LidAngle](https://github.com/deepakness/LidAngle) — documentation of HID vendor/product usage and feature-report format.
- [Apple's ScreenCaptureKit overview](https://developer.apple.com/documentation/screencapturekit) — screen capture API.

The implementation is written for this project using the macOS SDK. No third-party source or media is bundled.
