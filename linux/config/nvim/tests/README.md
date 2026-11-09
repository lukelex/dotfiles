# Neovim tabline regression checks

Run from the repository root with Neovim and the configured Tabby plugin installed:

```sh
nvim --headless -u NONE -l linux/config/nvim/tests/tabby.lua
```

The runner uses an isolated Neovim configuration and scratch tabs. It loads the
real Tabby renderer from `stdpath('data')/lazy/tabby.nvim`. Set `TABBY_NVIM_PATH`
if the plugin is installed elsewhere. No additional test framework is required.

Checks cover overflow, direct tab selection, scrolling and paging, viewport
anchoring, resizing, renaming, Unicode/percent labels, and tab lifecycle changes.
Picker checks replace `vim.ui.select` to exercise selection, cancellation,
hidden tabs, reordered tabs, and stale selections without opening an interactive UI.
Additional checks cover modified-buffer/window indicators, floating-window exclusion,
stable close-button spacing, truncation, colorscheme changes, browsing position,
and mouse-wheel routing.

## Tab controls

- `<leader>t[` / `<leader>t]`: scroll one tab left/right.
- `<leader>t{` / `<leader>t}`: scroll one viewport left/right.
- `<leader>tt`: search all tab numbers and full names using the configured
  fzf-lua UI selector; Enter switches to the selected native tab.
- `gt`, `gT`, and `{number}gt`: normal Neovim tab navigation.
- Mouse wheel over the bar: scroll the viewport; elsewhere, scroll normally.

Manual scrolling leaves the selected workspace unchanged. Selecting a tab,
including selecting the current tab through the picker, reveals it in the bar.

## Tab labels

- `●`: unsaved changes in a buffer displayed in a non-floating window of that tab.
- `×N`: number of non-floating windows, shown when there is more than one.
- Active tabs use the theme's selected color, are bold, and show a close button. Inactive tabs
  move their window count into the close-button slot, keeping the same total
  width so switching tabs does not move labels.
- Long paths keep their filename suffix; other long names retain both ends.
- While browsing, the footer shows the visible range and total, with an arrow
  toward the active tab when it is off-screen. Narrow layouts shorten or omit
  the footer to preserve space for the workspace label.

## LSP watcher regression checks

Run from the repository root on Linux with Neovim 0.12+, `fd`, and
`inotify-tools` installed:

```sh
nvim --headless -u NONE -i NONE -n -l linux/config/nvim/tests/lsp-watch.lua
nvim --headless -u NONE -i NONE -n -l linux/config/nvim/tests/lsp-watch-recovery.lua
```

The watcher test uses real background processes and temporary directories. It
checks exclusions under `/tmp` (including regex characters in workspace names),
shared watchers, independent subscriber filters, filenames containing whitespace,
automatic pruning of new/moved-in tmp trees, continuous events during watcher
handoff, and cancellation both during discovery and after startup. It does not load the
editor's plugins or modify saved sessions.
Discovery checks verify that only added subtrees are scanned, direct tmp creation
needs no scan, and moved-out exclusions are removed from the cache.

The recovery test injects process failures and advances retry timers deterministically.
It checks recovery, bounded backoff, preserving a healthy watcher during failed
handoff, and cancellation of pending retries.

## LSP root regression checks

```sh
nvim --headless -u NONE -i NONE -n -l linux/config/nvim/tests/lsp-roots.lua
```

Requires the configured `nvim-lspconfig` plugin (or `LSPCONFIG_NVIM_PATH`). Checks
Tailwind v3/v4, nested packages, Git boundaries, and Solargraph's Gemfile root.
No language servers are started or installed.

The `nvim-tests` CI job runs all three LSP suites on Ubuntu with Neovim 0.12.6,
`fd`, `inotify-tools`, and the `nvim-lspconfig` revision from `lazy-lock.json`.
