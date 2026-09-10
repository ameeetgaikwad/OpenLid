# Architecture

OpenLid is a dependency-free Swift package with a native AppKit entry point and SwiftUI settings window. The build script wraps the executable in a standard app bundle.

## Data flow

`Apple HID → LidSensor → AppModel → FoldState → FoldRenderer`

`ScreenCaptureKit → one retained pixel buffer → FoldRenderer → Metal drawable → built-in-display overlay`

- **FoldCore** is pure deterministic math: normalized preferences, bounded fold progress, style values, and HID report decoding. Sensor degrees are little-endian bytes 1–2 of feature report 1 and valid only in 0...180. Nonfinite angles clear the effect.
- **LidSensor** searches for vendor `0x05AC`, product `0x8104`, sensor usage page `0x20`, orientation usage `0x8A`. It opens non-exclusively, reads only, and closes handles on teardown. This is an undocumented hardware interface; runtime availability is the source of truth.
- **DesktopCapture** filters out the entire OpenLid process before starting a stream. No fallback captures the overlay. Stream output runs on a serial queue. The latest pixel buffer replaces the previous one under a lock, so render work cannot enqueue an unbounded frame backlog.
- **FoldRenderer** wraps Core Image's perspective projection, Gaussian blur, and shading with a Metal-backed `CIContext`. The projected frame sits over black within a click-through `NSPanel`. The panel is below the system menu bar and closes with the effect. The cursor stays untransformed so the menu-bar pause remains discoverable.
- **AppModel** coordinates capture startup, invalidation, teardown, preferences, and UI state on the main actor. A generation counter invalidates pending startup work and delayed renderer/stream callbacks; callbacks hop to the main actor and check their captured generation before changing the app. Pause waits for startup to settle before stopping that stream. New enables are disabled until teardown finishes. The renderer rejects stale capture frames.
- **SettingsView** uses original generated landscape artwork. Its manual preview does not capture the desktop or use simulated values as hardware input.

## Resource and lifecycle bounds

Capture uses SDR BGRA, maximum 1920px width, 30fps, three queued buffers, and no audio. Rendering pauses while the lid is above the clear threshold, but capture and 30 Hz sensor polling continue while enabled for responsiveness. There is no claim of zero idle power use.

Five consecutive bad sensor reads pause the effect. Blank/suspended/stopped capture output, a stream error, stale frames, sleep, lock, session change, or display topology change also pause. A 15-second active-fold timeout is a conservative alpha safeguard. Restart is explicit; no automatic capture resume after waking or unlocking.

## Packaging

SwiftPM builds the host architecture. `Resources/Info.plist` supplies the stable bundle identifier, macOS 14 minimum, and menu-bar-only policy. Local ad-hoc signing allows local testing; production distribution needs Developer ID signing, hardened runtime evaluation, notarization, and a tested release process.
