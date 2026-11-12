#!/usr/bin/bash

set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
temporary="$(mktemp -d)"
trap 'rm -rf "$temporary"' EXIT
mkdir -p "$temporary/home" "$temporary/bin"

cat > "$temporary/bin/dotpkg" <<'EOF'
#!/usr/bin/bash
[[ "$*" != 'wizard --help' ]] || exit 0
printf '%s\n' "$@" > "$INSTALL_TEST_ARGS"
EOF
chmod +x "$temporary/bin/dotpkg"

HOME="$temporary/home" XDG_CONFIG_HOME="$temporary/config" \
  DOTPKG_BIN="$temporary/bin/dotpkg" INSTALL_TEST_ARGS="$temporary/args" \
  bash "$repo_root/linux/install/all" --plain --yes --server --host archqms
cat > "$temporary/expected" <<EOF
wizard
--manifest
$repo_root/linux/packages.yaml
--root
$repo_root
--state-file
$temporary/config/dotpkg/state.yaml
--plain
--yes
--server
--host
archqms
EOF
cmp "$temporary/expected" "$temporary/args"

# Normal execution uses the installed frontend on PATH, without an override.
HOME="$temporary/home" XDG_CONFIG_HOME="$temporary/config" \
  PATH="$temporary/bin:$PATH" DOTPKG_BIN= INSTALL_TEST_ARGS="$temporary/path-args" \
  bash "$repo_root/linux/install/all" --plain --yes --server --host archqms
cmp "$temporary/expected" "$temporary/path-args"
for mode in --binary-path --cached-path; do
  resolved="$(HOME="$temporary/home" PATH="$temporary/bin:$PATH" DOTPKG_BIN= \
    bash "$repo_root/linux/install/dotpkg" "$mode")"
  [ "$resolved" = "$temporary/bin/dotpkg" ]
done

HOME="$temporary/home" XDG_CONFIG_HOME="$temporary/config" \
  DOTPKG_BIN="$temporary/bin/dotpkg" INSTALL_TEST_ARGS="$temporary/preview-args" \
  bash "$repo_root/linux/install/all" --dry-run --server </dev/null
grep -qx -- '--dry-run' "$temporary/preview-args"

# Preview without a frontend neither installs it nor initializes user state.
HOME="$temporary/home" XDG_CONFIG_HOME="$temporary/config" \
  DOTPKG_BIN="$temporary/missing" \
  bash "$repo_root/linux/install/all" --dry-run > "$temporary/preview"
grep -q 'No downloads or state changes' "$temporary/preview"
[ ! -e "$temporary/config" ]
[ -z "$(find "$temporary/home" -mindepth 1 -print -quit)" ]

if HOME="$temporary/home" DOTPKG_BIN="$temporary/bin/dotpkg" \
  bash "$repo_root/linux/install/all" --server </dev/null >"$temporary/error" 2>&1; then
  printf 'Expected non-TTY execution to require explicit plain mode\n' >&2
  exit 1
fi
grep -q 'terminal is required' "$temporary/error"
printf 'all wizard launcher: ok\n'
