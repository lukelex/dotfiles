#!/usr/bin/bash

set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
temporary="$(mktemp -d)"
trap 'rm -rf "$temporary"' EXIT
mkdir -p "$temporary/bin"
cat > "$temporary/bin/sudo" <<'EOF'
#!/usr/bin/bash
printf '%s\n' "$*" >> "$KMONAD_TEST_CALLS"
EOF
cat > "$temporary/bin/getent" <<'EOF'
#!/usr/bin/bash
# Exercise both an existing input group and a missing uinput group.
[ "$*" = 'group input' ]
EOF
chmod +x "$temporary/bin/"*
export PATH="$temporary/bin:$PATH" KMONAD_TEST_CALLS="$temporary/calls"

bash "$repo_root/linux/install/kmonad-device-manager" --dry-run > "$temporary/preview"
[ ! -e "$temporary/calls" ]
grep -q 'dry-run: sudo modprobe uinput' "$temporary/preview"
bash "$repo_root/linux/install/kmonad-device-manager" --server
bash "$repo_root/linux/install/kmonad-device-manager" --packages-only
[ ! -e "$temporary/calls" ]

bash "$repo_root/linux/install/kmonad-device-manager"
cat > "$temporary/expected" <<EOF
groupadd --system uinput
install -Dm644 $repo_root/linux/config/kmonad-device-manager/70-kmonad-uinput.rules /etc/udev/rules.d/70-kmonad-uinput.rules
install -Dm644 $repo_root/linux/config/kmonad-device-manager/uinput.conf /etc/modules-load.d/uinput.conf
modprobe uinput
udevadm control --reload-rules
udevadm trigger --action=add --subsystem-match=misc --sysname-match=uinput
udevadm settle
EOF
cmp "$temporary/expected" "$temporary/calls"

printf 'kmonad system setup: ok\n'
