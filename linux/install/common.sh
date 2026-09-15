#!/usr/bin/bash

DRY_RUN=0
export PACKAGES_ONLY=0
INSTALL_PROFILE=desktop
INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES="$(cd "$INSTALL_DIR/../.." && pwd)"
export DOTFILES
INSTALL_MANIFEST="$DOTFILES/linux/packages.yaml"
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

if [ -n "$INSTALL_HOST" ]; then
  host_manifest="$DOTFILES/linux/hosts/$INSTALL_HOST.yaml"
  [ -f "$host_manifest" ] || { printf 'Unknown host overlay: %s\n' "$INSTALL_HOST" >&2; exit 2; }
  INSTALL_MANIFEST="$(mktemp)"
  "$YQ" eval-all '. as $item ireduce ({}; . * $item)' "$DOTFILES/linux/packages.yaml" "$host_manifest" > "$INSTALL_MANIFEST"
fi

is_server() {
  [ "$INSTALL_PROFILE" = server ]
}

manifest_list() {
  "$YQ" -r "$1[]" "$INSTALL_MANIFEST"
}

manifest_packages() {
  "$YQ" -r "$1 | keys[]" "$INSTALL_MANIFEST"
}

manifest_package_origin() {
  local package="$1"
  local source
  source="$("$YQ" -r "[.. | select(tag == \"!!map\" and has(\"$package\")) | .[\"$package\"].source] | map(select(. != null)) | unique | .[]" "$INSTALL_MANIFEST")"
  if [ -n "$source" ]; then
    printf '%s\n' "$source"
  else
    "$YQ" -r '.source' "$INSTALL_MANIFEST"
  fi
}

manifest_option_names() {
  "$YQ" -r "$1 | keys[]" "$INSTALL_MANIFEST"
}

manifest_option_prompt() {
  "$YQ" -r "$1.prompt" "$INSTALL_MANIFEST"
}

manifest_option_default() {
  "$YQ" -r "$1.default" "$INSTALL_MANIFEST"
}

manifest_option_packages() {
  "$YQ" -r "$1.packages | keys[]" "$INSTALL_MANIFEST"
}

manifest_options_packages() {
  local options_path="$1"
  local option
  while IFS= read -r option; do
    manifest_option_packages "$options_path.$option"
  done < <(manifest_option_names "$options_path")
}

manifest_package_groups() {
  "$YQ" -r "($1) | .. | select((tag == \"!!map\") and has(\"groups\")) | .groups[]" "$INSTALL_MANIFEST"
}

manifest_package_configs() {
  "$YQ" -r "($1) | .. | select((tag == \"!!map\") and has(\"configs\")) | .configs[]" "$INSTALL_MANIFEST"
}

manifest_package_services() {
  local scope="$1"
  shift
  local category
  for category in "$@"; do
    "$YQ" -r "($category) | .. | select((tag == \"!!map\") and has(\"services\")) | .services.${scope}[]?" "$INSTALL_MANIFEST"
  done
}

group_logout_notice() {
  local message='LOG OUT AND BACK IN before using the updated group permissions.'
  if [ "$DRY_RUN" -eq 1 ]; then
    message='LOG OUT AND BACK IN will be required if group changes are applied.'
  fi

  printf '\n========================================================================\n'
  printf '  %s\n' "$message"
  printf '========================================================================\n\n'
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
