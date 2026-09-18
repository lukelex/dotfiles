# op-run-args.sh — single source of truth for how the 1Password CLI injects
# shared secrets. Sourced by both linux/scripts/op-run (bash) and
# linux/config/zsh/secrets.zsh (zsh), so keep this POSIX-ish and avoid
# zsh-only syntax beyond simple arrays. Intentionally has no shebang.
#
# shellcheck shell=bash
#
# Backends (OP_RUN_BACKEND):
#   refs         (default) stable secret references resolved from the *.env
#                files in $OPREFS_DIR.
#   environments (beta)    load every variable from one 1Password Environment,
#                named by $OP_ENVIRONMENT_ID. The *.env files in $OPREFS_DIR
#                still serve as the manifest of which variable names to load.
# Switching backends is a one-line change; the values live in 1Password either
# way.

# shellcheck disable=SC2034  # OP_RUN_ARGS/OP_REFS_FILES are consumed by the sourcing scripts
DOTFILES="${DOTFILES:-$HOME/dotfiles}"
OPREFS_DIR="${OPREFS_DIR:-$DOTFILES/linux/config/oprefs}"
OP_RUN_BACKEND="${OP_RUN_BACKEND:-refs}"
OP_ENVIRONMENT_ID="${OP_ENVIRONMENT_ID:-}"

# Refs files: a shared one plus an optional per-host overlay
# (secrets.<short-hostname>.env), loaded last so it takes precedence.
OP_REFS_FILES=("$OPREFS_DIR/secrets.env")
_host_short="$(hostname -s 2>/dev/null || printf 'unknown')"
[[ -f "$OPREFS_DIR/secrets.$_host_short.env" ]] && OP_REFS_FILES+=("$OPREFS_DIR/secrets.$_host_short.env")

if [[ "$OP_RUN_BACKEND" == "environments" && -n "$OP_ENVIRONMENT_ID" ]]; then
  OP_RUN_ARGS=(--environment "$OP_ENVIRONMENT_ID")
else
  OP_RUN_ARGS=()
  for _f in "${OP_REFS_FILES[@]}"; do
    [[ -f "$_f" ]] && OP_RUN_ARGS+=(--env-file "$_f")
  done
fi
unset _host_short _f