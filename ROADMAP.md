# Roadmap

This is a list of priorities, not delivery dates or compatibility promises. Propose changes through issues before undertaking large work.

## Before the first public binary release

- Complete the [manual validation checklist](docs/manual-validation.md) on supported MacBook hardware.
- Record a model/macOS compatibility table with actual test results.
- Validate capture startup, pause, static frames, lock/unlock, sleep/wake, display changes, and permission revocation.
- Measure CPU/GPU load, memory stability, power use, and rendering latency.
- Verify the helper's drag-and-drop behavior on supported macOS versions.
- Add an original app icon and a privacy-safe demo recorded from synthetic desktop content.
- Complete the repository and distribution setup in [releasing](docs/releasing.md).

## Next product work

- Improve consistency between the illustrative preview and live rendering.
- Investigate event-driven lid updates where hardware supports them.
- Evaluate Retina/HDR rendering and quality/performance controls from measurements.
- Add optional launch at login with an explicit user control.
- Consider optional sounds and reduced-motion behavior.

## Boundaries

Keep core functionality usable without an account or network connection. Do not add telemetry, remote capture, or recorded screen files as incidental implementation details. External display effects and sleep prevention are separate proposals, not current capabilities.
