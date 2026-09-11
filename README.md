# OpenLid

**A little more alive.** An independent, open-source macOS menu-bar app that responds to your MacBook lid as you close your MacBook lid.

Native Swift + SwiftUI, ScreenCaptureKit, and Metal compute and Metal Performance Shaders. No dependencies, accounts, telemetry, or subscriptions. MIT licensed.

> **Local alpha, not a validated release.** The native preview and automated checks can be tested without permissions. Physical lid behavior and the live capture pipeline still require testing on supported hardware before release. This is an original implementation inspired by [Bendy](https://trybendy.app/); no Bendy code, branding, or assets are included.

## Build and run

The [OpenLid website](https://ameeetgaikwad.github.io/OpenLid/) includes an interactive, illustrative preview of the three styles. An unnotarized testing prerelease is available from [GitHub Releases](https://github.com/ameeetgaikwad/OpenLid/releases).

Requires macOS 14+ and Swift 5.9+ (Xcode or Apple's Command Line Tools). The live effect requires a built-in display and an accessible Apple lid angle HID sensor. Not every Apple silicon MacBook exposes that sensor.

```sh
git clone https://github.com/ameeetgaikwad/OpenLid.git
cd OpenLid
bash scripts/build-app.sh
open dist/OpenLid.app
```

The script creates an ad-hoc signed app for the current architecture. It uses workspace-local compiler caches and does not need an Apple developer account. `--disable-sandbox` affects SwiftPM's manifest subprocess only; it does not change macOS security settings. There are no remote package dependencies.

Live mode needs Screen Recording access. Keep the app at a stable path; rebuilding an ad-hoc signed app may require refreshing its permission grant. Frames are processed locally and never saved or uploaded.

To package a local development DMG, run `bash scripts/build-dmg.sh`. It creates a host-architecture image and SHA-256 checksum in `dist/`, containing OpenLid and an Applications shortcut. This artifact is ad-hoc signed and not notarized; it is intended for alpha testing, with hardware validation still pending.

## Try it

1. Open the app. **Appearance** contains a manual preview that needs no screen access.
2. Drag **Preview lid angle**, choose **Paper**, **Dusk**, or **Mist**, and tune perspective, softness, and shadow.
3. In **General**, check sensor availability and set the angle above which the effect clears.
4. To use the real desktop, click **Enable live effect**. Allow Screen Recording in macOS if requested, then relaunch and enable again.
5. Gently lower the lid while keeping it open. The effect targets only the built-in display. Use the menu-bar laptop icon to pause.

Paper is the neutral baseline: inverse perspective, light gradient shading, and subtle blur. Dusk adds deeper shading and Mist adds softer focus. The styles share identical geometry and preserve colors. Softness and Shadow control those effects; there is no forced blackout shared by all styles.

The live effect is **paused on every launch**. Closing the settings window leaves the menu-bar app running. Escape pauses while OpenLid has keyboard focus; the menu-bar pause is the control to use from other apps. No global keyboard monitoring permission is requested.

## Safety and current limits

- Pause, sleep, screen lock, session changes, display reconfiguration, sensor failure, and capture failure hide the overlay, disconnect the sensor, and stop capture. Enable again manually afterward.
- Continuous folding has a 15-second safety timeout so the desktop cannot stay obscured indefinitely. The overlay ignores mouse input; the real menu bar remains above it.
- Capture targets up to 60 fps and 3840px width with three queued buffers. One frame is retained by the renderer. GPU/energy behavior needs hardware measurement.
- The current sensor implementation polls feature report 1 at 60 Hz while enabled. It does not reproduce Bendy's advertised event-driven sensor implementation. Discovery also reads one report on startup or recheck.
- Unsupported models get an explicit message and can still use preview. We do not request root privileges or use synthetic sensor data.
- The manual preview uses the production Metal renderer with generated artwork. Physical seated-view alignment requires testing with a real lid; the bounded inverse perspective is a tunable approximation.
- No startup-at-login, sounds, auto-update, external-display effects, or notarized download is shipped yet.
- This does not stop normal lid-close sleep and is not a clamshell utility.

## Developer checks

```sh
bash scripts/test.sh
bash scripts/build-app.sh
dist/OpenLid.app/Contents/MacOS/OpenLid --diagnostics
dist/OpenLid.app/Contents/MacOS/OpenLid --render-check
dist/OpenLid.app/Contents/MacOS/OpenLid --performance-check
```

Diagnostics print `lid_angle_degrees: <value>` or `unsupported: <reason>`, capture permission and renderer mode, and the macOS version. Diagnostics do not start capture or request permission. Please do not interpret a sensor read or a passing build as evidence that the live effect has been validated.

`--render-check` executes the production Metal pipeline on generated pixels. It checks full coverage, neutral colors, and zero-effect identity across styles and angles, and writes /tmp/openlid-neutral-render-check.png. It does not capture the screen. Physical lid motion and live capture are separate checks. `--performance-check` measures real sensor reads and generated-frame render latency without capturing the screen; it does not report live FPS.

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

Live mode receives desktop frames but no audio. Only the effect overlay is excluded, so other OpenLid windows remain visible. Captured frames stay in memory; only preferences are persisted. No network client, analytics, or crash-reporting SDK is included. See [PRIVACY.md](PRIVACY.md).

## References and credit

- [Bendy](https://trybendy.app/): product inspiration; an independent commercial app.
- [Sam Gold's LidAngleSensor](https://github.com/samhenrigold/LidAngleSensor): public discovery of the MacBook lid sensor and hardware caveats.
- [LidAngle](https://github.com/deepakness/LidAngle): documentation of HID vendor/product usage and feature-report format.
- [Apple ScreenCaptureKit](https://developer.apple.com/documentation/screencapturekit): capture API.

The implementation is written for this project using the macOS SDK. No third-party source or media is bundled.
