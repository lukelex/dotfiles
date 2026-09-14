#!/usr/bin/bash

DRY_RUN=0
INSTALL_PROFILE=desktop
INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_MANIFEST="$INSTALL_DIR/../packages.yaml"
YQ="$INSTALL_DIR/yq"
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

manifest_list() {
  "$YQ" -r "$1[]" "$INSTALL_MANIFEST"
}

manifest_packages() {
  "$YQ" -r "$1 | keys[]" "$INSTALL_MANIFEST"
}

manifest_package_groups() {
  "$YQ" -r "($1) | .. | select((tag == \"!!map\") and has(\"groups\")) | .groups[]" "$INSTALL_MANIFEST"
}

manifest_package_configs() {
  "$YQ" -r "($1) | .. | select((tag == \"!!map\") and has(\"configs\")) | .configs[]" "$INSTALL_MANIFEST"
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
