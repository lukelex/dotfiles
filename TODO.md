# TODO

## Screen locking

- [x] Add a read-only now-playing glance with album art to Hyprlock.
- [x] Add a contextual wallpaper treatment with time-of-day tinting.
- [x] Show dynamic mic/camera-in-use status on the lock screen.
- [x] Improve keyboard-state feedback, including Num Lock and failed-password guidance.
- [x] Polish multi-monitor locking with a primary authentication surface and secondary status displays.
- [x] Add a smooth unlock transition.
- [x] Defer idle locking for calls, presentations, fullscreen video, and media playback.
- [ ] Add a private lock-screen mode that hides notification titles.
- [ ] Add low-power OLED burn-in mitigation while locked.
- [ ] Consider authenticated emergency power controls.
- [ ] Add optional rotating quotes, focus intention, or weather.
- [x] Show a persistent "Screen will lock in 10 seconds" warning before idle locking in X11 and Hyprland.
- [x] Dismiss the idle-lock warning when activity resumes or locking begins.
- [x] Add a 60-second advance idle-lock warning.
- [x] Defer idle locking while Hyprland has an active fullscreen window or idle inhibitor.
- [ ] Show concise feedback while the lock screen is launching.
- [x] Hide notification message bodies on the lock screen.
- [ ] Make suspend and lid-close locking complete before the display powers down.
- [ ] Show the idle-lock timeout and active-inhibitor state in Control Center.
- [ ] Add a critical-battery lock and suspend policy.

## Lock-screen wow factors

- [x] Add fingerprint-first unlock feedback when an enrolled reader is available.
- [x] Add an animated ambient background with subtle parallax or grain.
- [x] Add an unlock progress state with verifying and success feedback.
- [x] Add a security event indicator for failed attempts and the last failed-attempt time.
- [x] Add adaptive layout based on wallpaper contrast and monitor orientation.
- [x] Add a battery ring/status capsule.
- [x] Show the current DND/focus state prominently.
- [ ] Add safe locked-screen quick actions for brightness, volume, microphone mute, and media.
- [ ] Move the clock subtly between locks to reduce OLED burn-in.
- [ ] Add optional weather and condition-only status.
- [ ] Add a session handoff animation after unlocking.
- [ ] Add an optional time-aware personal greeting.

## Hyprlock / Quickshell theme revamp

- [x] Match Hyprlock's dark and light palettes to Quickshell's bar tokens.
- [x] Replace the legacy orange password field with the shared slate/blue visual language.
- [x] Make the clock, date, account, password prompt, keyboard layout, and Caps Lock state legible at common display scales.
- [x] Show side-effect-free battery percentage, charge state, and time remaining/to-full.
- [x] Show current network, VPN, audio mute/volume, and Do Not Disturb status.
- [x] Improve lock-screen notification history with a heading, total/overflow count, bounded cards, urgency treatment, and safe escaped text.
- [x] Keep notification rendering durable while the session lock hides normal notification surfaces.
- [x] Generate a theme-aware Hyprlock config immediately before lock acquisition; keep direct Hyprlock invocation usable with the dark default.
- [x] Make logind/hypridle lock requests launch the actual locker rather than merely calling `loginctl`.
- [x] Keep the lock path independent of generated `u_*` links and cover it with a CI regression test.
- [ ] Validate manual lock, idle lock, suspend/resume, no-battery desktops, unavailable network/VPN services, light/dark themes, scaled displays, and notification updates while locked.
- [ ] Run shellcheck, notification-renderer tests, `hyprlock --config`, and `git diff --check` after implementation.
