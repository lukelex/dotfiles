#!/usr/bin/bash
set -Eeuo pipefail
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
temporary=$(mktemp -d)
trap 'rm -rf "$temporary"' EXIT
export HOME="$temporary/home" XDG_RUNTIME_DIR="$temporary" CAPTURE_LOG="$temporary/capture"
mkdir -p "$HOME" "$temporary/bin"
export PATH="$temporary/bin:$PATH"
cat > "$temporary/bin/hyprctl" <<'EOF'
#!/usr/bin/bash
case "$1" in
  activewindow) echo '{"mapped":true,"hidden":false,"at":[10,20],"size":[300,400]}' ;;
  monitors) echo '[{"focused":true,"name":"DP-1"}]' ;;
esac
EOF
cat > "$temporary/bin/slurp" <<'EOF'
#!/usr/bin/bash
echo '1,2 30x40'
EOF
cat > "$temporary/bin/grim" <<'EOF'
#!/usr/bin/bash
printf '%s\n' "$@" > "$CAPTURE_LOG"
printf 'original capture' > "${@: -1}"
EOF
cat > "$temporary/bin/satty" <<'EOF'
#!/usr/bin/bash
if [ "${EDIT_SUCCESS:-0}" = 1 ]; then
  printf 'annotated capture' > "$4"
  exit 0
fi
# Simulate an editor which truncates output and then crashes.
printf '' > "$4"
exit 1
EOF
for command in wl-copy play notify-send; do
  printf '#!/usr/bin/bash\nexit 1\n' > "$temporary/bin/$command"
done
chmod +x "$temporary/bin/"*
for mode in region window output; do
  bash "$repo/linux/scripts/screenshot" "$mode"
  case "$mode" in
    region) grep -Fx '1,2 30x40' "$CAPTURE_LOG" ;;
    window) grep -Fx '10,20 300x400' "$CAPTURE_LOG" ;;
    output) grep -Fx 'DP-1' "$CAPTURE_LOG" ;;
  esac
done
count=0
for capture in "$HOME/screenshots/"*.png; do
  [ "$(cat "$capture")" = 'original capture' ]
  count=$((count + 1))
done
[ "$count" = 3 ]
if bash "$repo/linux/scripts/screenshot" invalid; then exit 1; fi
# Successful edits replace the capture, but failed promotion retains it.
EDIT_SUCCESS=1 bash "$repo/linux/scripts/screenshot" region
grep -l 'annotated capture' "$HOME/screenshots/"*.png > /dev/null
cat > "$temporary/bin/mv" <<'EOF'
#!/usr/bin/bash
# Edited images must already be on the destination filesystem.
[[ "$(dirname "$1")" == "$HOME/screenshots/.edit-"* ]] && touch "$HOME/staged-edit"
exit 1
EOF
chmod +x "$temporary/bin/mv"
EDIT_SUCCESS=1 bash "$repo/linux/scripts/screenshot" region
[ -f "$HOME/staged-edit" ]
count=$(grep -l 'original capture' "$HOME/screenshots/"*.png | wc -l)
[ "$count" = 4 ]
# A fresh install without the editor must still save captures. Restrict PATH
# so an editor installed on the test host cannot accidentally satisfy the test.
rm "$temporary/bin/satty"
for command in mkdir jq mktemp date rm cp; do
  ln -s "$(command -v "$command")" "$temporary/bin/$command"
done
PATH="$temporary/bin" /usr/bin/bash "$repo/linux/scripts/screenshot" region
count=0
for capture in "$HOME/screenshots/"*.png; do
  count=$((count + 1))
done
[ "$count" = 6 ]
[ "$(grep -l 'original capture' "$HOME/screenshots/"*.png | wc -l)" = 5 ]
# Cancelling selection must not create a saved image or invoke capture.
printf '#!/usr/bin/bash\nexit 1\n' > "$temporary/bin/slurp"
rm "$CAPTURE_LOG"
if bash "$repo/linux/scripts/screenshot" region; then exit 1; fi
[ ! -e "$CAPTURE_LOG" ]
shopt -s nullglob
leftovers=("$HOME/screenshots/".edit-* "$temporary/"screenshot-*.png)
[ "${#leftovers[@]}" -eq 0 ]
printf 'screenshot tests: ok\n'
