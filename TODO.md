# TODO

## Screen locking

- [x] Show a persistent "Screen will lock in 10 seconds" warning before idle locking in X11 and Hyprland.
- [x] Dismiss the idle-lock warning when activity resumes or locking begins.
- [x] Add a 60-second advance idle-lock warning.
- [x] Defer idle locking while Hyprland has an active fullscreen window or idle inhibitor.
- [ ] Show concise feedback while the lock screen is launching.
- [ ] Hide notification message bodies on the lock screen.
- [ ] Make suspend and lid-close locking complete before the display powers down.
- [ ] Show the idle-lock timeout and active-inhibitor state in Control Center.
- [ ] Add a critical-battery lock and suspend policy.

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
