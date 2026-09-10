# Manual validation — required before release

Status: physical lid and real screen-capture testing deferred to the user. Automated tests and a working preview are not substitutes.

Use a supported MacBook with its built-in display active. Keep the lid comfortably open throughout this check; do not force the hinge.

- [ ] Build and open `dist/OpenLid.app`. Verify it starts paused, with a menu-bar laptop icon.
- [ ] Without granting Screen Recording, drag the preview angle between 35° and 120°. Confirm visible folding and a clear open state.
- [ ] Select Paper, Dusk, and Mist. Check sliders and relaunch to confirm preference persistence.
- [ ] Run `--diagnostics`. Confirm a physical angle changes as the lid moves; an unsupported result must not be replaced with simulated data.
- [ ] Click Enable. Deny permission first; verify the normal desktop remains visible and the UI explains the missing permission.
- [ ] Grant Screen Recording to the stable app location, relaunch, and enable. Verify macOS's capture indicator and no audio capture.
- [ ] Move the physical lid through two distinct angles below the clear threshold. Verify actual app windows and wallpaper fold together with no recursive overlay image.
- [ ] Reopen above the clear angle. Verify the overlay disappears immediately.
- [ ] Pause from the menu bar while another app is focused. Verify the overlay and capture indicator stop.
- [ ] Rapidly enable/pause and close/reopen settings. Verify no orphaned stream, stale overlay, or disabled controls remain.
- [ ] Lock/unlock, sleep/wake, and connect/disconnect a display. Verify capture pauses and requires explicit enable afterward.
- [ ] Hold the effect active for 15 seconds; verify the safety timeout restores the desktop.
- [ ] Revoke Screen Recording permission while enabled. Confirm capture failure clears the overlay.
- [ ] Check Spaces, full-screen apps, display scaling, cursor access, static desktop behavior, and external-display exclusion.
- [ ] Measure idle/active CPU, GPU and energy usage, memory stability, rendering latency, and screen clarity before claiming performance targets.

Record hardware model, macOS version, app commit/build, permission state, checks performed, and failures. Do not record or share screen contents that contain personal information.
