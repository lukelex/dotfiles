#!/usr/bin/bash

DRY_RUN=0
export PACKAGES_ONLY=0
INSTALL_PROFILE=desktop
INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES="$(cd "$INSTALL_DIR/../.." && pwd)"
export DOTFILES
INSTALL_HOST=""
YQ="$INSTALL_DIR/yq"
for arg in "$@"; do
  case $arg in
    --dry-run|--check) DRY_RUN=1 ;;
    --packages-only) PACKAGES_ONLY=1 ;;
    --server) INSTALL_PROFILE=server ;;
    --desktop) INSTALL_PROFILE=desktop ;;
    --host=*) INSTALL_HOST="${arg#--host=}" ;;
  esac
done

for ((index = 1; index <= $#; index++)); do
  if [ "${!index}" = "--host" ]; then
    next=$((index + 1))
    INSTALL_HOST="${!next:-}"
  fi
done

[ -z "$INSTALL_HOST" ] || [ -f "$DOTFILES/linux/hosts/$INSTALL_HOST.yaml" ] || {
  printf 'Unknown host overlay: %s\n' "$INSTALL_HOST" >&2
  exit 2
}

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
