# Architecture

OpenLid is a dependency-free Swift package with AppKit lifecycle and SwiftUI settings.

## Data flow

Apple HID -> LidSensor -> LidMotion -> FoldState -> FoldRenderer
ScreenCaptureKit -> retained pixel buffer -> CVMetalTextureCache -> compiled Metal / MPS blur -> display overlay

- FoldCore sanitizes settings and sensor data. The inverse perspective expands the top edge and vertical extent around the fixed bottom edge. Cropping fills the output, avoiding the former shrinking transform's black gap. This is a tunable bounded approximation, not eye-tracked physical calibration.
- Paper is the neutral baseline. Dusk increases shadow and Mist increases blur. All three share geometry and preserve color; there are no color washes. Softening grows late in the close motion. Shading is a neutral vertical gradient.
- LidMotion uses elapsed-time exponential smoothing with faster reopening. SensorSampler performs all recurring HID reads on a serial background queue; the animation loop reads a locked snapshot. Sensor sampling and display updates target 60 Hz. The settings UI receives changed angles at most four times per second.
- DesktopCapture temporarily registers an empty transparent effect panel, then excludes that exact window by ID and owning process. It does not exclude other OpenLid windows. Failure to identify the overlay stops startup. Capture is bounded at 3840 pixels wide, up to 60 fps, three queued buffers, no audio.
- AppModel retains the panel, renderer, stream, and startup task. A generation token rejects late callbacks. Pause hides immediately and waits for cancelled startup before stopping/draining that session; a new enable is blocked until cleanup completes. Capture must provide an initial frame within three seconds.
- FoldRenderer maps a retained CVPixelBuffer directly to a Metal texture. MetalEffectPipeline compiles inverse-perspective and neutral-shading shaders once and caches Gaussian blur kernels in quarter-pixel sigma steps. Two reusable intermediate textures support MPS blur. At most two frames are in flight; extra work is dropped rather than queued. Capture requests sRGB and the shader performs linear-light processing. The original Core Image graph is retained only as a regression reference. Overlay ordering changes only on visibility transitions.
- EffectPreview renders generated artwork through the same FoldRenderer graph as live mode. It redraws only when its own effect state changes. The preview matches screen-space math, not the physical viewing angle of a tilted MacBook.

## Lifecycle and limits

Five bad sensor reads, capture errors, sleep, lock, session resignation, display changes, or 15 seconds continuously active pause. Escape pauses only while OpenLid has focus. It does not prevent normal lid-close sleep.

## Validation

Core checks cover bounds, monotonic geometry, frame-rate-independent smoothing, settings, and sensor parsing. --render-check executes the production Metal graph and checks opaque full coverage, neutral RGB values, and zero-effect identity. It saves a generated comparison sheet. Real seated-view matching, permission behavior, and physical lifecycle scenarios require separate live validation.

## Performance diagnostics

--performance-check exercises two real sensor sampler start/sample/stop cycles, measures 60 synchronous HID reads, and benchmarks 90 warmed-up frames of the actual Metal pipeline at 2560x1664 with generated artwork, Mist, 70 percent softness, and changing angles. It does not capture the screen. CPU submission, GPU, and completion timings exclude capture, window presentation, and physical motion. See performance.md for the measured comparison.
