# Neovim diagnostics and regression checks

## Memory diagnostics

`:NvimMemory` opens an asynchronous Linux `/proc` snapshot for this editor and
its descendants, including the separate Neovim TUI, LSP servers and their workers.
Use `r` to refresh and `q` to close. The report shows PSS, private RAM, RSS, and
proportional swap in MiB. Prefer PSS totals: summing RSS counts shared pages more
than once. Unavailable measurements are shown as `?`, with totals marked partial.
The snapshot helper itself and other Neovim sessions are excluded. Remote or
detached servers outside the process tree cannot be measured this way. Active
LSP workspace names are listed separately; they are not guessed from process IDs.

```sh
python3 -B linux/config/nvim/tests/memory-snapshot.py
nvim --headless -u NONE -i NONE -n -l linux/config/nvim/tests/memory.lua
```

## Tabline tests

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
nvim --headless -u NONE -i NONE -n -l linux/config/nvim/tests/lsp-watch-outage.lua
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
Discovery and watcher readiness each have a 30-second deadline. A timeout kills
the hung process and uses the existing bounded retries. Tests also deliver late
completion/readiness callbacks to ensure timed-out processes cannot take over.

The outage test uses two real LSP fixture subprocesses. It changes an unopened
file during a watcher outage, observes the stale server cache, then verifies
reinitialization reads the missed change and reattaches unsaved buffer text.
Unrelated workspaces are retained. Clients overlapping the recovered root are
restarted because LSP has no standard full-workspace rescan request; a failed
replacement with a still-healthy active watcher does not require a restart.
This was also reproduced with the installed Tailwind server: changing a v4
theme color during an outage left hover showing the old color after watcher-only
recovery. Reinitialization refreshes that state.

### Watcher diagnostics

`:LspWatchStatus` shows the backend and each root's lifecycle phase, subscriber
count, process IDs, exclusions, retry budget/total, lost-coverage flag, and most
recent error with its timestamp. It is read-only and does not restart anything.
The command prints up to eight exclusions per root; the complete structured
snapshot is available with `:lua vim.print(require('core.lsp-watch').status())`.
Cancelled roots disappear from the snapshot. Error history belongs to the current
root instance, so reinitializing its clients may create a fresh instance.

## LSP root regression checks

```sh
nvim --headless -u NONE -i NONE -n -l linux/config/nvim/tests/lsp-roots.lua
```

Requires the configured `nvim-lspconfig` plugin (or `LSPCONFIG_NVIM_PATH`). Checks
Tailwind v3/v4, nested packages, Git boundaries, and Solargraph's Gemfile root.
No language servers are started or installed.

The `nvim-tests` CI job runs the LSP suites on Ubuntu with Neovim 0.12.6,
`fd`, `inotify-tools`, and the `nvim-lspconfig` revision from `lazy-lock.json`.

## Full-session startup profiling

With the normal plugins and language servers already installed:

```sh
python linux/config/nvim/scripts/profile-startup.py ~/projects/SimplerQMS
python linux/config/nvim/scripts/profile-startup.py ~/projects/SimplerQMS --treesitter async
```

This runs the real TUI in a 180×50 pseudo-terminal for 20 seconds. It restores a
temporary copy of the saved session and disables session autosave and ShaDa writes.
Plugins and language servers run normally, including their usual logs and caches.
Terminal probes are answered so missing DSR responses do not distort timings.
Use `--seconds`, `--session`, or `--output` to customize the run. Output directories
must be new; the default is a temporary directory printed at completion.

Each run retains `startup.log`, `terminal.log`, and `result.json`. Results include
startup/restore timing, 10 ms heartbeat gaps, client attachment times and roots,
loaded buffers, notifications, and synchronous subprocess calls taking over 10 ms.
The post-restore gap excludes the heartbeat spanning session restoration; it
measures subsequent responsiveness while language servers start. Timings describe
the synthetic terminal and local cache state, not an interactive typing benchmark.

### SimplerQMS measurement — 2026-11-09

Two warm-cache runs per mode with Neovim 0.12.6, four restored buffers (YAML,
TypeScript, and two Ruby files), and 15-second observation windows:

| Tree-sitter mode | Startup | Session restoration | Largest post-restore gap |
| --- | --- | --- | --- |
| Configured synchronous parsing | 263–268 ms | 209–213 ms | 20–30 ms |
| Asynchronous parsing | 261–262 ms | 208–209 ms | 20–27 ms |

Solargraph and StandardRB used the backend root; ESLint and TypeScript used the
E2E root. Tailwind did not start for these buffers. No synchronous subprocess
call exceeded 10 ms. There was no repeat of the multi-second post-open freeze.
The Tree-sitter difference was small relative to run-to-run variation, so the
configured parsing mode was retained. Session restoration accounted for most
startup work, rather than delayed LSP watcher registration.

## Large-file Tree-sitter budget

```sh
nvim --headless -u NONE -i NONE -n -l linux/config/nvim/tests/treesitter-budget.lua
nvim --headless -u NONE -i NONE -n -l linux/config/nvim/scripts/benchmark-treesitter.lua
nvim --headless -u NONE -i NONE -n -l linux/config/nvim/scripts/benchmark-treesitter.lua --guarded
# Or measure an existing source file:
nvim --headless -u NONE -i NONE -n -l linux/config/nvim/scripts/benchmark-treesitter.lua path/to/source.ts
```

The benchmark uses installed parsers and scratch buffers. It measures synchronous
initial and incremental parsing, not total editor/UI latency. On 2026-11-09:

| Fixture | Initial parse | Incremental parse |
| --- | --- | --- |
| Normal 173 KB JavaScript locale file | 10 ms | 3 ms |
| 10,000 generated TypeScript/Ruby/YAML lines | 93–101 ms | <1–50 ms |
| 30,000 generated TypeScript/Ruby/YAML lines | 258–310 ms | <1–142 ms |
| One-line 600 KB JavaScript | 164 ms | 80 ms |

With `--guarded`, those large fixtures skip parsing; protection took 0.04–0.30 ms.

Buffers at least 512 KiB or 10,000 lines skip automatic Tree-sitter highlighting,
indentation, endwise, and configured textobjects. Regex syntax highlighting is
also disabled for these buffers. The check uses in-memory buffer metadata and
runs on file load/filetype changes and edits, so growth is covered. The reason
is available in `b:treesitter_size_limit`. After shrinking a file, reload it or
reapply its filetype to reenable automatic features. Ordinary files retain the
existing synchronous parsing behavior. The guard test runs in CI without parsers.
