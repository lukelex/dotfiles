#!/usr/bin/bash

set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
temporary="$(mktemp -d)"
trap 'rm -rf "$temporary"' EXIT

home="$temporary/home"
bin="$temporary/bin"
mkdir -p "$home" "$bin"
ln -s "$repo_root" "$home/dotfiles"

cat > "$bin/hyprlock" <<'EOF'
#!/usr/bin/bash
printf '%s\n' "$@" > "$LOCK_ARGUMENTS"
EOF
cat > "$bin/u_music" <<'EOF'
#!/usr/bin/bash
exit 0
EOF
cat > "$bin/qs" <<'EOF'
#!/usr/bin/bash
exit 0
EOF
chmod +x "$bin/hyprlock" "$bin/u_music" "$bin/qs"

LOCK_ARGUMENTS="$temporary/arguments" \
  HOME="$home" \
  XDG_SESSION_TYPE=wayland \
  PATH="$bin:/usr/bin:/bin" \
  bash "$repo_root/linux/scripts/exit" lock

expected_config="$home/.cache/dotfiles/hyprlock.conf"
[ -f "$expected_config" ] || { printf 'lock wrapper did not generate its config\n' >&2; exit 1; }
grep -Fx -- '--config' "$temporary/arguments" > /dev/null
grep -Fx -- "$expected_config" "$temporary/arguments" > /dev/null
grep -F 'linux/scripts/lock-status' "$expected_config" > /dev/null

printf 'lock launcher: ok\n'
