#!/usr/bin/bash
set -Eeuo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
temporary="$(mktemp -d)"
trap 'rm -rf "$temporary"' EXIT
cp -a "$repo_root/linux" "$temporary/linux"
mkdir -p "$temporary/home" "$temporary/bin"
export HOME="$temporary/home" XDG_CONFIG_HOME="$temporary/home/.config"
export DOTPKG_BIN="$temporary/bin/dotpkg" TEST_LOG="$temporary/log"
cat > "$DOTPKG_BIN" <<'EOF'
#!/usr/bin/bash
printf '%s\n' "$@" >> "$TEST_LOG"
exit "${TEST_DOTPKG_FAIL:-0}"
EOF
chmod +x "$DOTPKG_BIN"
for helper in openeffects openeffects-state; do
  cat > "$temporary/linux/install/$helper" <<'EOF'
#!/usr/bin/bash
printf '%s\n' "${0##*/}" >> "$TEST_LOG"
if [ "${0##*/}" = openeffects ]; then exit "${TEST_PACKAGE_FAIL:-0}"; fi
EOF
done
bash "$temporary/linux/install/optional" skills --server --dry-run
grep -Fxq "$temporary/linux/optional/skills.yaml" "$TEST_LOG"
grep -Fxq "$XDG_CONFIG_HOME/dotpkg/optional-skills/state.yaml" "$TEST_LOG"
if grep -q 'openeffects' "$TEST_LOG"; then exit 1; fi
[ ! -e "$XDG_CONFIG_HOME" ]
: > "$TEST_LOG"
bash "$temporary/linux/install/optional" effects --replace --restart-services
head -n 2 "$TEST_LOG" | cmp - <(printf 'openeffects-state\nopeneffects\n')
grep -Fxq "$XDG_CONFIG_HOME/dotpkg/optional-effects/state.yaml" "$TEST_LOG"
grep -Fxq -- --replace "$TEST_LOG"
grep -Fxq -- --restart-services "$TEST_LOG"
: > "$TEST_LOG"
if TEST_PACKAGE_FAIL=1 bash "$temporary/linux/install/optional" effects > "$temporary/error" 2>&1; then
  echo 'Expected failure before resource reconciliation' >&2
  exit 1
fi
if grep -Fxq sync "$TEST_LOG"; then exit 1; fi
grep -q 'completed steps are retained' "$temporary/error"
if TEST_DOTPKG_FAIL=1 bash "$temporary/linux/install/optional" skills --server > "$temporary/error" 2>&1; then
  echo 'Expected optional resource failure' >&2
  exit 1
fi
grep -q 'Retry: linux/install/optional skills' "$temporary/error"
if grep -q 'stage completed' "$temporary/error"; then exit 1; fi

# Core maintenance must not invoke either optional installer.
for helper in preflight bootstrap-yay kmonad-device-manager binaries; do
  printf '#!/bin/bash\nexit 0\n' > "$temporary/linux/install/$helper"
done
for helper in openeffects openeffects-state; do
  printf '#!/bin/bash\necho "unexpected optional call" >&2\nexit 99\n' > "$temporary/linux/install/$helper"
done
bash "$temporary/linux/install/sync"
"$repo_root/linux/install/yq" -e '.resources.remote_bundles == null and ([.resources.services[].name] | contains(["openeffectsd.service"]) | not)' "$repo_root/linux/packages.yaml" >/dev/null
printf 'Optional stage isolation and failure recovery: ok\n'
