# Resolve only 1Password references. Failed loads never import partial output or
# print resolver errors (which may contain sensitive data). Retry after unlocking
# with `secrets-retry`; shell startup never waits indefinitely for authentication.
[[ -n "${NO_1PASSWORD:-}" ]] && return 0
source "$DOTFILES/linux/config/oprefs/op-run-args.sh" || return 0

secrets-retry() {
  local -a keys
  local k v f pairs
  command -v op >/dev/null 2>&1 || {
    print -r -- 'secrets: 1Password CLI unavailable; install it, then run secrets-retry.' >&2
    return 1
  }
  for f in "${OP_REFS_FILES[@]}"; do
    [[ -f "$f" ]] || continue
    while IFS= read -r k; do
      [[ -n "$k" ]] && keys+=("$k")
    done < <(grep -oE '^[A-Za-z_][A-Za-z0-9_]*=' "$f" | sed 's/=$//')
  done
  keys=("${(@u)keys}")
  (( ${#keys[@]} )) || return 0

  # zsh preserves NUL bytes in command substitutions. Capture status before
  # importing anything, keeping resolved values in memory rather than a file.
  # This private pipe needs real values, not op's default concealed placeholders.
  if ! pairs=$(timeout --kill-after=1s 3s op run --no-masking "${OP_RUN_ARGS[@]}" -- \
      zsh "$OPREFS_DIR/print-pairs.zsh" "${keys[@]}" 2>/dev/null); then
    print -r -- 'secrets: 1Password load failed or timed out; unlock it and run secrets-retry.' >&2
    return 1
  fi
  while IFS= read -r -d $'\0' k && IFS= read -r -d $'\0' v; do
    [[ -n "$v" ]] && export "$k=$v"
  done < <(printf '%s' "$pairs")
  return 0
}

secrets-retry || true
