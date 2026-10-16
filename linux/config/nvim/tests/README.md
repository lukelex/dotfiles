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
  Snacks UI selector; Enter switches to the selected native tab.
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
