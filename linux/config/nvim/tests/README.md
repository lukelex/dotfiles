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

## Tab controls

- `<leader>t[` / `<leader>t]`: scroll one tab left/right.
- `<leader>t{` / `<leader>t}`: scroll one viewport left/right.
- `<leader>tt`: search all tab numbers and full names using the configured
  Snacks UI selector; Enter switches to the selected native tab.
- `gt`, `gT`, and `{number}gt`: normal Neovim tab navigation.

Manual scrolling leaves the selected workspace unchanged. Selecting a tab,
including selecting the current tab through the picker, reveals it in the bar.
