# Contributing to OpenLid

Use macOS 14+ and the Swift toolchain. No package installation is needed.

## Getting started

Fork [OpenLid](https://github.com/ameeetgaikwad/OpenLid), clone your fork, and make a focused branch for your change. Read the [architecture](docs/architecture.md) for the capture/rendering flow and [roadmap](ROADMAP.md) for priorities.

1. Build with `bash scripts/build-app.sh`.
2. Test with `bash scripts/test.sh`.
3. Run `dist/OpenLid.app/Contents/MacOS/OpenLid --diagnostics` to check local sensor support without capture.
4. For rendering, permissions, sensor, or lifecycle changes, run [manual validation](docs/manual-validation.md) and report exactly which checks you ran.

Before submitting, run `bash scripts/check.sh`. This is the same command CI uses: shell syntax, app metadata, core tests, release build, and bundle signature verification. It does not request screen permissions or test physical lid movement. There is no separate Swift linter configured; compilation performs type checking.

## Proposing a change

Search existing issues before opening one. Use the bug or feature form, and discuss large changes before implementing them. Keep pull requests focused, explain the before/after behavior, and include validation and remaining limitations. Add regression coverage when it can catch the reported defect; do not substitute core math tests for a required hardware check. Update CHANGELOG.md for user-visible changes.

Follow the existing Swift style and macOS 14 API baseline. Use structured concurrency carefully around capture startup/teardown, keep UI mutations on the main actor, and document any new OS or hardware requirement. Do not reset other contributors' edits or include local build/session files in your PR.

## Project expectations

Keep the app local-only. Do not introduce frame storage, telemetry, network dependencies, privileged helpers, or permission escalation without a clearly discussed need. Invalid or stale sensor input must restore the real desktop. Capture must exclude OpenLid and must stop cleanly.

Use original assets or include license and attribution for any new third-party material. Contributions are under the repository's MIT license. Report hardware model and macOS version for compatibility findings; omit serial numbers and screen contents. Do not claim support for a model that has not been physically tested.

Suggested next work: event-driven sensor access where supported, measured GPU/battery use, pixel-matched preview/live rendering, broader hardware validation, signed/notarized releases, and accessible launch-at-login controls.

Participating means following the [Code of Conduct](CODE_OF_CONDUCT.md). Report sensitive vulnerabilities using [SECURITY.md](SECURITY.md), not a public bug report. Contributions remain under the repository's MIT license; no additional CLA is required by this project.
