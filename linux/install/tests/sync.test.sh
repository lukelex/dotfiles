#!/usr/bin/bash

set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
temporary="$(mktemp -d)"
trap 'rm -rf "$temporary"' EXIT

cp -a "$repo_root/linux" "$temporary/linux"
mkdir -p "$temporary/bin" "$temporary/home" "$temporary/linux/hosts"
printf '{}\n' > "$temporary/linux/hosts/laptop.yaml"
printf '%s\n' '#!/usr/bin/bash' 'exit 0' > "$temporary/linux/install/preflight"
printf '%s\n' '#!/usr/bin/bash' 'exit 0' > "$temporary/linux/install/bootstrap-yay"
printf '%s\n' '#!/usr/bin/bash' 'printf "%s\\n" "$@" > "$DOTPKG_TEST_ARGS"' > "$temporary/bin/dotpkg"
chmod +x "$temporary/linux/install/preflight" "$temporary/linux/install/bootstrap-yay" "$temporary/bin/dotpkg"

PATH="$temporary/bin:$PATH" HOME="$temporary/home" DOTFILES="$temporary" \
  XDG_STATE_HOME="$temporary/state" DOTPKG_BIN="$temporary/bin/dotpkg" \
  DOTPKG_YES=1 DOTPKG_TEST_ARGS="$temporary/full-args" \
  bash "$temporary/linux/install/sync" --desktop --host laptop --dry-run --replace --restart-services
cat > "$temporary/expected-full" <<EOF
sync
--profile
desktop
--host
$temporary/linux/hosts/laptop.yaml
--dry-run
--yes
--resources
--root
$temporary
--replace
--restart-services
EOF
cmp "$temporary/expected-full" "$temporary/full-args"

PATH="$temporary/bin:$PATH" HOME="$temporary/home" DOTFILES="$temporary" \
  XDG_STATE_HOME="$temporary/state" DOTPKG_BIN="$temporary/bin/dotpkg" \
  DOTPKG_TEST_ARGS="$temporary/packages-args" \
  bash "$temporary/linux/install/sync" --server --packages-only --dry-run
cat > "$temporary/expected-packages" <<EOF
sync
--profile
server
--dry-run
EOF
cmp "$temporary/expected-packages" "$temporary/packages-args"

printf 'sync command: ok\n'
