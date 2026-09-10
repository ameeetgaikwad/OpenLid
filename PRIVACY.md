# Privacy

OpenLid has no accounts, telemetry, network client, remote logging, or automatic updates.

When the user enables the live effect, ScreenCaptureKit captures the built-in display, excluding OpenLid itself. Other visible applications and documents on that display are included. Audio capture is disabled. Frames are held in memory and rendered locally through Core Image and Metal; no recording output or file writer exists. Pausing stops the stream and releases the retained frame after pending capture callbacks drain.

The appearance preview is drawn from local geometric artwork and does not capture the screen. Sensor discovery reads the Apple lid orientation sensor; live mode polls it at 30 Hz. The app does not request Accessibility, Input Monitoring, microphone, or camera permissions.

Appearance preferences are stored in UserDefaults under the app's bundle identifier, `org.openlid.OpenLid`. The enabled state is never persisted. Diagnostic output includes macOS version, permission status, and an angle or unsupported reason. Diagnostic output should be reviewed before sharing it publicly.

macOS owns the Screen Recording permission prompt and its own capture indicators. Revoking access in System Settings prevents subsequent capture. This document describes the source implementation; operating-system internals and other applications are outside OpenLid's control.
