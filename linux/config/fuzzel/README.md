# Fuzzel themes

- **Super+D** opens the app launcher.
- **Super+Ctrl+D** opens the theme chooser, then previews your selection in the launcher.
- **Super+Ctrl+C** opens clipboard history using the selected theme.

Slate is the default. Graphite is compact and text-only; Porcelain uses the
Quickshell light palette. Selection is stored in `$XDG_STATE_HOME/fuzzel/theme`
(normally `~/.local/state/fuzzel/theme`). Canceling the chooser preserves it.
Run `u_fuzzel --theme` to choose from a terminal.

`common.ini` contains shared behavior; `themes/*.ini` hold the visual variants.
Direct `fuzzel` invocations use Slate; use `u_fuzzel` for the remembered theme.
App-launch frequency is shared between themes through Fuzzel's standard cache.

After updating from the old single-file configuration, apply the manifest with
`./linux/install/sync --desktop --refresh-manifest --replace`. This also installs
the `u_fuzzel` helper link. The replacement flag allows the new config directory
link to replace the old directory containing `fuzzel.ini`.
