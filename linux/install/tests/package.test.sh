#!/usr/bin/bash

set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
temporary="$(mktemp -d)"
trap 'rm -rf "$temporary"' EXIT

fail() {
  printf '%s\n' "$1" >&2
  exit 1
}

cp -a "$repo_root/linux" "$temporary/linux"
mkdir "$temporary/bin" "$temporary/home"

printf '%s\n' '#!/usr/bin/bash' 'if [ "$1" = -Slq ]; then printf "%s\\n" candidate-package; fi' > "$temporary/bin/pacman"
printf '%s\n' '#!/usr/bin/bash' \
  'printf "{\"results\":["' \
  'separator=""' \
  'for arg in "$@"; do' \
  '  case $arg in' \
  '    arg\[\]=*) printf "%s{\\\"Name\\\":\\\"%s\\\"}" "$separator" "${arg#arg[]=}"; separator="," ;;' \
  '  esac' \
  'done' \
  'printf "]}\n"' > "$temporary/bin/curl"
chmod +x "$temporary/bin/pacman" "$temporary/bin/curl"
printf '%s\n' '#!/usr/bin/bash' 'exit 0' > "$temporary/bin/sudo"
chmod +x "$temporary/bin/sudo"

bash "$repo_root/linux/install/package" --help >/dev/null
bash "$repo_root/linux/install/package" add --help >/dev/null
bash "$repo_root/linux/install/package" sync --help >/dev/null
bash "$repo_root/linux/install/package" validate --help >/dev/null

PATH="$temporary/bin:$PATH" HOME="$temporary/home" XDG_STATE_HOME="$temporary/state" \
  bash "$temporary/linux/install/package" add candidate-package --scope desktop --dry-run > "$temporary/output"
cmp "$repo_root/linux/packages.yaml" "$temporary/linux/packages.yaml" >/dev/null \
  || fail 'Dry-run modified the manifest'
output="$(<"$temporary/output")"
[[ "$output" == *'Validated '* ]] || fail 'Candidate package was not validated'
[[ "$output" == *'dry-run: add candidate-package to desktop'* ]] || fail 'Dry-run did not report the manifest change'

PATH="$temporary/bin:$PATH" HOME="$temporary/home" XDG_STATE_HOME="$temporary/state" \
  bash "$temporary/linux/install/package" add candidate-package --dry-run > "$temporary/default-output"
output="$(<"$temporary/default-output")"
[[ "$output" == *'dry-run: default package scope is desktop'* ]] || fail 'Dry-run did not select the desktop scope'

if PATH="$temporary/bin:$PATH" HOME="$temporary/home" XDG_STATE_HOME="$temporary/state" \
  bash "$temporary/linux/install/package" add candidate-package --scope hyprland --dry-run >/dev/null 2>&1; then
  fail 'Unselected Hyprland scope unexpectedly succeeded'
fi

mkdir -p "$temporary/fonts/fa6/svgs" "$temporary/state/dotfiles/install"
printf '%s\n' \
  'version: 1' \
  'current:' \
  '  profile: desktop' \
  '  host: ""' \
  '  selections:' \
  '    extras: false' \
  '    hyprland: false' \
  '    i3: false' \
  '    options:' \
  '      ipod: false' \
  '      nvidia: false' \
  '      nvidia-gui: false' \
  '      optional: false' \
  'managed:' \
  '  packages: []' \
  '  groups: []' \
  '  configs: []' \
  '  services: []' > "$temporary/state/dotfiles/install/state.yaml"
printf 'y\n' | PATH="$temporary/bin:$PATH" HOME="$temporary/home" XDG_STATE_HOME="$temporary/state" DOTPKG_PACKAGE_STAGE=0 \
  bash "$temporary/linux/install/package" add tracked-example --scope desktop >/dev/null
"$temporary/linux/install/yq" -e '.profiles.desktop.packages.desktop | has("tracked-example")' "$temporary/linux/packages.yaml" >/dev/null \
  || fail 'Package was not added to the requested scope'
"$temporary/linux/install/yq" -e '.managed.packages | contains(["tracked-example"])' "$temporary/state/dotfiles/install/state.yaml" >/dev/null \
  || fail 'Installed package was not tracked'

printf 'package command: ok\n'
