#!/usr/bin/bash

set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
temporary="$(mktemp -d)"
trap 'rm -rf "$temporary"' EXIT

mkdir -p "$temporary/bin"
printf '%s\n' '#!/usr/bin/bash' 'exit 0' > "$temporary/bin/yay"
chmod +x "$temporary/bin/yay"

PATH="$temporary/bin:$PATH" bash "$repo_root/linux/install/bootstrap-yay"

output="$(PATH="$temporary/bin:$PATH" bash "$repo_root/linux/install/bootstrap-yay" --dry-run)"
[ -z "$output" ] || { printf 'bootstrap should skip when yay is installed\n' >&2; exit 1; }

output="$(/usr/bin/bash -c '
  command() {
    if [ "$1" = -v ] && [ "$2" = yay ]; then
      return 1
    fi
    builtin command "$@"
  }
  source "$1" --dry-run
' _ "$repo_root/linux/install/bootstrap-yay")"
[ "$output" = 'dry-run: install base-devel and git with pacman, then build yay from the AUR' ]

printf 'yay bootstrap: ok\n'
