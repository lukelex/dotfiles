# Sound mixer

Open the existing audio panel from the bar or `Super+Ctrl+V`. Its compact view
contains default output/microphone selection, master levels/mute, microphone
metering and the existing all-microphone mute action.

The Sound settings action opens System Settings → Audio. All nuanced controls
live there, alongside the portable volume/microphone key-step preferences.
The bar widget contains no application mixer, ports, profiles or amplification.

In System Settings, application streams are grouped by application/process identity. Playback and
recording have independent volume, mute and device routing; paused streams stay
visible. Applications with more than two streams expand to show individual
controls rather than pretending differing routes or volumes are one value.
Recording stream mute affects that stream, not device access permissions.
System-audio recording sources are labeled separately from microphones.

Changing the default output/input still moves running streams, as before. Routes
chosen for individual streams are live state, not persistent per-app exceptions.

Device settings expand inline for non-default device levels/mute, available
connectors and supported card modes. Changing mode can interrupt sound, remove
devices or trade Bluetooth playback quality for microphone support. Channel/boost
details expose independent channel levels and optional amplification to 150%;
the ordinary linked control is capped at 100% and preserves relative balance.
Disabling the boost UI does not silently reduce an already-amplified device.

The shared mixer subscribes to Pulse-compatible events only while System Settings
is visible on Audio, coalesces updates and reconciles every five seconds. Commands use arguments,
not shell interpolation. Each backend call has a four-second timeout; requests
revalidate the captured object identity and verify resulting state. Errors appear
beside the target, or globally if it disappears. Closing drops unsent edits;
an already-running operation finishes. Nothing is written to repo preferences.

The Audio section also opens pavucontrol for speaker tests and less common
workflows. Application/output peak meters and persistent per-app routing are not
implemented; the existing visible, unmuted-microphone meter remains unchanged.

Validation: `node --test linux/config/quickshell/tests/audio-mixer.test.cjs` uses
mocked pactl state to cover levels, channel balance, recording mute, system-audio
routing, modes/ports, stale targets, failed confirmation and stable/coalesced QML
models. Tests do not alter the user's live audio state.
