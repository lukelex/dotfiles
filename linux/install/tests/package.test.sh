#!/usr/bin/bash

set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
temporary="$(mktemp -d)"
trap 'rm -rf "$temporary"' EXIT

cp -a "$repo_root/linux" "$temporary/linux"
mkdir -p "$temporary/bin" "$temporary/home"
printf '%s\n' '#!/usr/bin/bash' 'printf "%s\\n" "$@" > "$DOTPKG_TEST_ARGS"' > "$temporary/bin/dotpkg"
chmod +x "$temporary/bin/dotpkg"

bash "$repo_root/linux/install/package" --help >/dev/null
bash "$repo_root/linux/install/package" add --help >/dev/null
bash "$repo_root/linux/install/package" sync --help >/dev/null
bash "$repo_root/linux/install/package" validate --help >/dev/null

PATH="$temporary/bin:$PATH" HOME="$temporary/home" XDG_STATE_HOME="$temporary/state" \
  DOTPKG_BIN="$temporary/bin/dotpkg" DOTPKG_TEST_ARGS="$temporary/add-args" \
  bash "$temporary/linux/install/package" add candidate-package --scope desktop --dry-run
cat > "$temporary/expected-add-args" <<EOF
add
--manifest
$temporary/linux/packages.yaml
--state-file
$temporary/state/dotfiles/install/state.yaml
candidate-package
--scope
desktop
--dry-run
EOF
cmp "$temporary/expected-add-args" "$temporary/add-args"

PATH="$temporary/bin:$PATH" HOME="$temporary/home" XDG_STATE_HOME="$temporary/state" \
  DOTPKG_BIN="$temporary/bin/dotpkg" DOTPKG_TEST_ARGS="$temporary/validate-args" \
  bash "$temporary/linux/install/package" validate --server --host laptop --package candidate-package
cat > "$temporary/expected-validate-args" <<EOF
validate
--manifest
$temporary/linux/packages.yaml
--state-file
$temporary/state/dotfiles/install/state.yaml
--server
--host
laptop
--package
candidate-package
EOF
cmp "$temporary/expected-validate-args" "$temporary/validate-args"

PATH="$temporary/bin:$PATH" HOME="$temporary/home" XDG_STATE_HOME="$temporary/state" \
  DOTPKG_BIN="$temporary/bin/dotpkg" DOTPKG_TEST_ARGS="$temporary/sync-args" \
  bash "$temporary/linux/install/package" sync --desktop --dry-run
cat > "$temporary/expected-sync-args" <<EOF
sync
--manifest
$temporary/linux/packages.yaml
--state-file
$temporary/state/dotfiles/install/state.yaml
--desktop
--dry-run
EOF
cmp "$temporary/expected-sync-args" "$temporary/sync-args"

printf 'package command: ok\n'
