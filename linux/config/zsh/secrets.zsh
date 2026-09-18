# secrets.zsh — load shared environment variables from 1Password into the
# interactive shell. The values come from 1Password (op:// references in
# linux/config/oprefs/secrets.env); nothing secret is stored on this machine.
#
# Skips out quietly when: `op` is missing, NO_1PASSWORD=1 is set, or the vault
# is locked. If it was locked at startup, the load is retried once on the next
# prompt after unlocking (the desktop app unlocks at login, so this usually
# happens within seconds).
#
# Debug: set OP_SECRETS_DEBUG=1 to see what this file decides to do.

source "$DOTFILES/linux/config/oprefs/op-run-args.sh" || return 0

command -v op >/dev/null 2>&1 || {
  [[ -n "${OP_SECRETS_DEBUG:-}" ]] && print -r -- "secrets: op not found, skipping" >&2
  return 0
}
[[ -n "${NO_1PASSWORD:-}" ]] && {
  [[ -n "${OP_SECRETS_DEBUG:-}" ]] && print -r -- "secrets: NO_1PASSWORD set, skipping" >&2
  return 0
}

_op_secrets_load() {
  local -a keys
  local k v f

  # The refs files double as the manifest of which variables to load, kept in
  # one place regardless of backend.
  keys=()
  for f in "${OP_REFS_FILES[@]}"; do
    [[ -f "$f" ]] || continue
    while IFS= read -r k; do
      [[ -n "$k" ]] && keys+=("$k")
    done < <(grep -oE '^[A-Za-z_][A-Za-z0-9_]*' "$f" 2>/dev/null)
  done
  keys=("${(@u)keys}")
  (( ${#keys[@]} )) || return 1

  # `op run` resolves the references and exports the vars into its subprocess;
  # print-pairs.zsh streams them back NUL-delimited so values with spaces,
  # quotes, or newlines are imported without eval. NOTE: missing/unresolvable
  # keys print an empty value here and are skipped.
  while IFS= read -r -d $'\0' k && IFS= read -r -d $'\0' v; do
    [[ -n "$v" ]] && export "$k=$v"
  done < <(op run "${OP_RUN_ARGS[@]}" -- zsh "$OPREFS_DIR/print-pairs.zsh" "${keys[@]}" 2>/dev/null)
}

_op_secrets_finish() {
  unset -f _op_secrets_load _op_secrets_retry _op_secrets_finish
}

_op_secrets_retry() {
  # Retry at most once: the desktop app has had a moment to unlock by now.
  add-zsh-hook -d precmd _op_secrets_retry
  _op_secrets_load && _op_secrets_finish
}

if op whoami >/dev/null 2>&1; then
  [[ -n "${OP_SECRETS_DEBUG:-}" ]] && print -r -- "secrets: unlocked, loading" >&2
  _op_secrets_load && _op_secrets_finish
else
  [[ -n "${OP_SECRETS_DEBUG:-}" ]] && print -r -- "secrets: locked, will retry on next prompt" >&2
  autoload -Uz add-zsh-hook
  add-zsh-hook precmd _op_secrets_retry
fi