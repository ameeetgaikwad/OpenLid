# Changelog

Changes are recorded here before a release is tagged. This file does not imply that a downloadable release exists.

## Unreleased

### Added

- Native macOS menu-bar app with a manual folding preview.
- Paper, Dusk, and Mist appearance styles, saved effect settings, and an adjustable clear angle.
- Read-only MacBook lid sensor discovery and diagnostics.
- ScreenCaptureKit capture and Metal-backed Core Image rendering for the built-in display.
- Pause controls and lifecycle safeguards, including a continuous-fold timeout.
- Floating Screen Recording helper with an app-file drag source, Finder fallback, and permission check.
- Dependency-free build and core test scripts, generated-pixel renderer diagnostic, and macOS CI configuration.
- MIT license and contributor, privacy, security, and community documentation.

### Fixed

- Closing direction now brings the top edge toward the viewer.
- Stale capture callbacks are scoped to their session.
- Unsuccessful sensor discovery closes its handles.

### Validation limits

- Physical lid/live desktop behavior and permission lifecycle tests remain pending.
- No signed, notarized public release has been produced.
