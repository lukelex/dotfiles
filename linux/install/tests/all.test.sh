#!/usr/bin/bash

set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
temporary="$(mktemp -d)"
trap 'rm -rf "$temporary"' EXIT

cp -a "$repo_root/linux" "$temporary/linux"
mkdir -p "$temporary/home"

for helper in sync configs-system icons kmonad-device-manager post verify; do
  printf '#!/usr/bin/bash\nprintf "%%s\\n" %s >> "$INSTALL_TEST_STEPS"\n' "$helper" > "$temporary/linux/install/$helper"
  chmod +x "$temporary/linux/install/$helper"
done

INSTALL_TEST_STEPS="$temporary/desktop" HOME="$temporary/home" DOTFILES="$temporary" \
  bash "$temporary/linux/install/all" --desktop
cmp <(printf 'sync\nconfigs-system\nicons\nkmonad-device-manager\npost\nverify\n') "$temporary/desktop"

INSTALL_TEST_STEPS="$temporary/server" HOME="$temporary/home" DOTFILES="$temporary" \
  bash "$temporary/linux/install/all" --server
cmp <(printf 'sync\npost\nverify\n') "$temporary/server"

INSTALL_TEST_STEPS="$temporary/packages" HOME="$temporary/home" DOTFILES="$temporary" \
  bash "$temporary/linux/install/all" --desktop --packages-only
cmp <(printf 'sync\n') "$temporary/packages"

printf 'all command: ok\n'
