# nwg-hello Theme Notes

- Keep this greeter visually aligned with `../hypr/hyprlock.conf` where the
  concepts overlap. Treat hyprlock's slate palette, Hack Nerd Font Mono,
  cool-blue accents, restrained rounded surfaces, clock, and date as shared
  design tokens; update both configs when those shared choices change.
- Greeter-only controls (user/session selection, login, and power actions) are
  unique to nwg-hello. Lock-only status widgets and authentication behavior do
  not need a greeter counterpart.
- nwg-hello reads its config and stylesheet from `/etc/nwg-hello/`; the files
  here are source templates. Keep their install/copy instructions and config
  keys aligned with upstream nwg-hello, and don't assume lock-session scripts
  or the logged-in user's private files are accessible to greetd's greeter user.
