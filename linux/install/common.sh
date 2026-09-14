#!/usr/bin/bash

DRY_RUN=0
INSTALL_PROFILE=desktop
for arg in "$@"; do
  case $arg in
    --dry-run|--check) DRY_RUN=1 ;;
    --server) INSTALL_PROFILE=server ;;
    --desktop) INSTALL_PROFILE=desktop ;;
  esac
done

is_server() {
  [ "$INSTALL_PROFILE" = server ]
}

run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "dry-run: $*"
    return 0
  fi
  "$@"
}

ask() {
  local prompt="$1"
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "dry-run: $prompt (auto-yes)" >&2
    printf 'y\n'
    return
  fi
  local answer
  read -rp "$prompt" answer
  printf '%s\n' "$answer"
}
