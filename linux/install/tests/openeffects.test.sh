#!/usr/bin/bash

set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
temporary="$(mktemp -d)"
trap 'rm -rf "$temporary"' EXIT
mkdir -p "$temporary/bin"
export TEST_LOG="$temporary/log"
export PATH="$temporary/bin:$PATH"

cat > "$temporary/bin/uname" <<'EOF'
#!/usr/bin/bash
printf 'x86_64\n'
EOF
cat > "$temporary/bin/pacman" <<'EOF'
#!/usr/bin/bash
if [ "$1" = -Q ]; then
  [ -n "${TEST_VERSION:-}" ] || exit 1
  printf '%s %s\n' "$2" "$TEST_VERSION"
else
  printf 'pacman %s\n' "$*" >> "$TEST_LOG"
fi
EOF
cat > "$temporary/bin/vercmp" <<'EOF'
#!/usr/bin/bash
case "$1" in
  0.1.4-1) printf '0\n' ;;
  0.2.0-1) printf '1\n' ;;
  *) printf '%s\n' -1 ;;
esac
EOF
cat > "$temporary/bin/curl" <<'EOF'
#!/usr/bin/bash
printf 'curl\n' >> "$TEST_LOG"
while [ "$#" -gt 0 ]; do
  if [ "$1" = --output ]; then printf 'test package\n' > "$2"; exit 0; fi
  shift
done
exit 1
EOF
cat > "$temporary/bin/sha256sum" <<'EOF'
#!/usr/bin/bash
cat >> "$TEST_LOG"
[ "${TEST_BAD_CHECKSUM:-0}" = 0 ]
EOF
cat > "$temporary/bin/sudo" <<'EOF'
#!/usr/bin/bash
exec "$@"
EOF
chmod +x "$temporary/bin/"*

bash "$repo_root/linux/install/openeffects" --server
[ ! -f "$TEST_LOG" ]
bash "$repo_root/linux/install/openeffects" --dry-run
[ ! -f "$TEST_LOG" ]
TEST_VERSION=0.1.4-1 bash "$repo_root/linux/install/openeffects"
[ ! -f "$TEST_LOG" ]
TEST_VERSION=0.2.0-1 bash "$repo_root/linux/install/openeffects"
[ ! -f "$TEST_LOG" ]

DOTPKG_YES=1 bash "$repo_root/linux/install/openeffects"
[ "$(grep -c '^curl$' "$TEST_LOG")" = 3 ]
grep -q '^pacman -U --needed --noconfirm ' "$TEST_LOG"
for name in openeffectsd openeffectsctl openeffects; do
  grep -q "/$name-0.1.4-1-x86_64.pkg.tar.zst" "$TEST_LOG"
done

: > "$TEST_LOG"
if TEST_BAD_CHECKSUM=1 bash "$repo_root/linux/install/openeffects"; then
  printf 'Expected checksum failure\n' >&2
  exit 1
fi
! grep -q '^pacman ' "$TEST_LOG"
printf 'OpenEffects installer: ok\n'
