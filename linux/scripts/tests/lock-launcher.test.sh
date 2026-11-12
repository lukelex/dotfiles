#!/usr/bin/bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
temporary="$(mktemp -d)"
trap 'rm -rf "$temporary"' EXIT
export HOME="$temporary/home" XDG_RUNTIME_DIR="$temporary/runtime"
export XDG_CACHE_HOME="$temporary/cache" LOCK_ARGUMENTS="$temporary/arguments"
mkdir -p "$HOME" "$XDG_RUNTIME_DIR" "$temporary/bin"
ln -s "$repo_root" "$HOME/dotfiles"
export PATH="$temporary/bin:/usr/bin:/bin"

cat > "$temporary/bin/hyprlock" <<'EOF'
#!/usr/bin/bash
printf '%s\n' "$@" >> "$LOCK_ARGUMENTS"
cp "$2" "$LOCK_ARGUMENTS.config"
EOF
cat > "$temporary/bin/i3lock" <<'EOF'
#!/usr/bin/bash
printf '%s\n' "$@" > "$LOCK_ARGUMENTS"
EOF
cat > "$temporary/bin/hyprctl" <<'EOF'
#!/usr/bin/bash
if [[ ${HANG_RENDER:-} == 1 ]]; then sleep 60; fi
printf '[]\n'
EOF
for command in fprintd-list magick qs; do
  printf '#!/usr/bin/bash\nexit 1\n' > "$temporary/bin/$command"
done
chmod +x "$temporary/bin/"*

# A stalled compositor query is bounded as part of the full render budget.
HANG_RENDER=1 timeout -k 1 5 "$repo_root/linux/scripts/hyprlock"
grep -F 'placeholder_text = Password' "$LOCK_ARGUMENTS.config" > /dev/null
grep -Fx -- '--grace' "$LOCK_ARGUMENTS" > /dev/null

# Rendering errors also use a standalone config with no external resources.
printf '#!/usr/bin/bash\nexit 1\n' > "$temporary/bin/python3"
chmod +x "$temporary/bin/python3"
timeout -k 1 5 "$repo_root/linux/scripts/hyprlock"
grep -F 'placeholder_text = Password' "$LOCK_ARGUMENTS.config" > /dev/null

# X11 image generation cannot hold the actual locker behind a stuck xrandr.
touch "$HOME/wallpaper.png"
printf '#!/usr/bin/bash\nsleep 60\n' > "$temporary/bin/xrandr"
chmod +x "$temporary/bin/xrandr"
timeout -k 1 5 "$repo_root/linux/scripts/blurlock"
grep -Fx -- '--color' "$LOCK_ARGUMENTS" > /dev/null
grep -Fx -- '--nofork' "$LOCK_ARGUMENTS" > /dev/null
printf 'lock launcher: ok\n'
