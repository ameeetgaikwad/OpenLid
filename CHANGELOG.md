# Changelog

Changes are recorded here before a release is tagged. This file does not imply that a downloadable release exists.

## Unreleased

- Dusk now fades substantially darker; Paper gains a warm matte finish and a shaded crease with minimal blur. Mist remains the default soft-focus style.

## 0.1.0-alpha.4 - 2026-09-11

- Start fresh app settings with Mist selected, matching the website. Existing saved style preferences are preserved.

## 0.1.0-alpha.3 - 2026-09-11

- Replace per-frame Core Image graph work with reusable Metal compute pipelines and cached Metal Performance Shaders blur.
- Move lid sensor sampling off the UI thread, limit queued rendering, and avoid redundant preview and window updates.
- Keep the desktop covered during lid motion, preserve OpenLid settings in capture, and use the same renderer for the generated preview.
- Distinguish Paper, Dusk, and Mist with neutral shading and softness.
- Add generated-frame performance diagnostics and pixel/geometry checks.
- Select Mist by default on the website and link its primary buttons to the Apple silicon alpha installer.
- Remove the floating permission helper in favor of the macOS Screen Recording flow.

Validation: 4462 core assertions and 21 generated-pixel checks passed. Local rendering measurements are documented in `docs/performance.md`; they do not measure sustained live FPS. This alpha remains ad-hoc signed and not notarized.

## Earlier alpha development

### Added

- Static website with an interactive three-style preview and GitHub Pages deployment.
- Development DMG packaging with an Applications shortcut and SHA-256 checksum.

- Native macOS menu-bar app with a manual folding preview.
- Paper, Dusk, and Mist appearance styles, saved effect settings, and an adjustable clear angle.
- Read-only MacBook lid sensor discovery and diagnostics.
- ScreenCaptureKit capture and Metal-backed Core Image rendering for the built-in display.
- Pause controls and lifecycle safeguards, including a continuous-fold timeout.
- Floating Screen Recording helper with an app-file drag source, Finder fallback, and permission check.
- Dependency-free build and core test scripts, generated-pixel renderer diagnostic, and macOS CI configuration.
- MIT license and contributor, privacy, security, and community documentation.

### Fixed

- DMG now opens in a configured drag-to-Applications layout with installation instructions and an original app icon.


- Closing direction now brings the top edge toward the viewer.
- Stale capture callbacks are scoped to their session.
- Unsuccessful sensor discovery closes its handles.

### Validation limits

- Physical lid/live desktop behavior and permission lifecycle tests remain pending.
- No signed, notarized public release has been produced.
