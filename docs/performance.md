# Render performance investigation

Date: 2026-09-11. Machine: Apple M3. User reported roughly 10-FPS-feeling lid animation. No running OpenLid process was available for the initial live sample, so that reported FPS was not measured.

## Findings and changes

Synchronous sensor reads measured 0.35 ms median, 0.52 ms p95, 0.64 ms max in the baseline. These reads were not the dominant measured cost but were moved off the UI thread to avoid any blocking HID latency there.

The original live path prepared a Core Image graph for every draw, ordered the overlay front every timer tick, and published sensor updates to SwiftUI at animation rate. The optimized path uses reusable Metal compute pipelines, direct CVMetalTextureCache mapping, cached MPS Gaussian kernels, two bounded in-flight frames, a locked background sensor snapshot, visibility transitions only, and unchanged-preview deduplication.

## Same generated-frame benchmark

2560x1664, Mist 70 percent softness, varying angles, 10 warmup plus 90 measured frames. These numbers exclude ScreenCaptureKit, WindowServer presentation, other apps, and physical movement.

| Metric | Baseline | Packaged optimized build |
| --- | ---: | ---: |
| CPU submission median | 6.75 ms | 0.06 ms |
| CPU submission p95 | 9.49 ms | 0.20 ms |
| GPU median | 3.29 ms | 2.15 ms |
| GPU p95 | 6.08 ms | 2.39 ms |
| Complete median | 12.72 ms | 2.56 ms |
| Complete p95 | 17.79 ms | 2.98 ms |
| Complete maximum | 63.99 ms | 4.26 ms |

A prior optimized run measured 2.46 ms median, 2.82 ms p95, and 2.95 ms max. After adding mipmaps for generated preview artwork, the final run measured 2.60 ms complete median, 3.76 ms p95, and 39.04 ms maximum. The maximum included a 35.93 ms CPU submission spike; GPU time stayed at or below 2.65 ms. These bounded samples show a lower typical rendering cost but do not establish sustained live FPS or eliminate all scheduling stalls.

## Verification

- Core suite: 8 checks, 4462 assertions, zero failures.
- Render checks: 21 pixel/geometry checks. Generated output has full coverage and neutral colors. Zero-effect identity and upper-shadow direction pass. Optimized geometry is compared to the previous Core Image graph using structured artwork.
- Two real sensor sampler start/sample/stop cycles passed, with fresh cached samples and cleared state after stop.
- Release build, type checking, metadata/shell checks, signature, and diff checks passed.
- Source review: HID access is queue-confined, sample state locked, capture cleanup awaits pending startup and stops the sampler, and an unresponsive sampler clears the overlay after 0.5 seconds without a fresh sample.

Remaining: sustained live frame timing with capture, physical tilt perception, HDR/Spaces/full-screen cases, sensor failure injection, and prolonged power/thermal behavior. No synthetic input is presented as physical hardware evidence. No commit, push, or deployment occurred.
