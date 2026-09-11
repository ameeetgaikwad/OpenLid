# Privacy

OpenLid has no accounts, telemetry, network client, remote logging, or automatic updates.

Live mode requests Screen Recording permission. ScreenCaptureKit captures the built-in display while excluding only the effect overlay. Other visible windows, including OpenLid settings, are part of the capture. Frames remain in memory and are rendered locally with Metal and Metal Performance Shaders. Audio capture is disabled. No screenshot, video, or audio writer is used by live mode.

The preview and render diagnostics use generated artwork, never desktop pixels. The renderer diagnostic writes only generated artwork to /tmp/openlid-neutral-render-check.png.

The Apple lid orientation sensor is read at 60 Hz on a serial background queue while enabled. Pause hides the overlay immediately, cancels pending startup, stops the capture stream, drains frame callbacks, and releases the retained frame. Sleep, lock, session changes, display changes, sensor failure, capture failure, and a 15-second active timeout pause the effect. Launch starts paused.

Appearance preferences persist in UserDefaults under org.openlid.OpenLid. The app does not request Accessibility, Input Monitoring, microphone, or camera access. Permission grants and capture indicators are controlled by macOS. Diagnostics read permission state without requesting it and include the sensor angle and macOS version. This describes the current local source; published builds may differ.
