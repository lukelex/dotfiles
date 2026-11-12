#!/usr/bin/bash

# Shared by the privileged installers. Never replace an unrelated target
# without an explicit --replace, and retain its contents for manual recovery.
replace=0
for arg in "$@"; do
  [ "$arg" != --replace ] || replace=1
done
path_conflicts=0

prepare_target() {
  local target="$1" backup
  if [ -e "$target" ] || [ -L "$target" ]; then
    if [ "$replace" -eq 0 ]; then
      printf 'Preserving conflicting path: %s (use --replace to back up and replace)\n' "$target" >&2
      path_conflicts=$((path_conflicts + 1))
      return 3
    fi
    if [ "$DRY_RUN" -eq 1 ]; then
      printf 'dry-run: back up %s beside its target\n' "$target"
    else
      backup="$(sudo mktemp -d "$(dirname "$target")/.dotfiles-backup-XXXXXXXX")" || return 1
      [ -n "$backup" ] && [ -d "$backup" ] || return 1
      sudo mv -- "$target" "$backup/$(basename "$target")" || return 1
      printf 'Backup retained: %s\n' "$backup"
    fi
  fi
  run sudo mkdir -p -- "$(dirname "$target")" || return 1
  return 0
}

install_link() {
  local source="$1" target="$2" status actual expected
  if [ -L "$target" ]; then
    actual="$(readlink -m "$target")" || return 1
    expected="$(readlink -m "$source")" || return 1
    [ "$actual" != "$expected" ] || return 0
  fi
  # Conditional calls disable errexit inside the callee. Only status 3 means a
  # deliberately preserved conflict; every operation must propagate failures.
  if prepare_target "$target"; then
    run sudo ln -s -- "$source" "$target" || return 1
  else
    status=$?
    [ "$status" -eq 3 ] || return "$status"
  fi
  return 0
}

install_copy() {
  local source="$1" target="$2" status
  if [ ! -L "$target" ] && [ -f "$target" ]; then
    if cmp -s "$source" "$target"; then
      return 0
    else
      status=$?
      [ "$status" -eq 1 ] || return 1
    fi
  fi
  if prepare_target "$target"; then
    run sudo install -m 0644 -- "$source" "$target" || return 1
  else
    status=$?
    [ "$status" -eq 3 ] || return "$status"
  fi
  return 0
}
