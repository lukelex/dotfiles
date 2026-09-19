#!/usr/bin/bash

set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
temporary="$(mktemp -d)"
trap 'rm -rf "$temporary"' EXIT

cp -a "$repo_root/linux" "$temporary/linux"
mkdir -p "$temporary/bin" "$temporary/home" "$temporary/fonts/fa6/svgs"

cat > "$temporary/bin/pacman" <<'EOF'
#!/usr/bin/bash
exit 0
EOF
cat > "$temporary/bin/sudo" <<'EOF'
#!/usr/bin/bash
exit 0
EOF
cat > "$temporary/bin/dotpkg" <<'EOF'
#!/usr/bin/bash
printf '%s\n' "$@" > "$DOTPKG_TEST_ARGS"
EOF
chmod +x "$temporary/bin/pacman" "$temporary/bin/sudo" "$temporary/bin/dotpkg"

mkdir -p "$temporary/state/dotfiles/install"
cat > "$temporary/state/dotfiles/install/state.yaml" <<'EOF'
version: 1
current:
  profile: desktop
  host: ""
  selections:
    extras: false
    hyprland: false
    i3: false
    options:
      ipod: false
      nvidia: false
      nvidia-gui: false
      optional: false
managed:
  packages: []
  groups: []
  configs: []
  services: []
EOF

PATH="$temporary/bin:$PATH" \
HOME="$temporary/home" \
DOTFILES="$temporary" \
XDG_STATE_HOME="$temporary/state" \
DOTPKG_PACKAGE_STAGE=1 \
DOTPKG_BIN="$temporary/bin/dotpkg" \
DOTPKG_YES=1 \
DOTPKG_TEST_ARGS="$temporary/args" \
  bash "$temporary/linux/install/sync" --packages-only --dry-run >/dev/null

cat > "$temporary/expected" <<EOF
sync
--manifest
$temporary/linux/packages.yaml
--state-file
$temporary/state/dotfiles/install/state.yaml
--profile
desktop
--dry-run
--yes
EOF
cmp "$temporary/expected" "$temporary/args"

printf 'dotpkg package stage: ok\n'
