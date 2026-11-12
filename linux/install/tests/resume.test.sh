#!/usr/bin/bash

set -Eeuo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
temporary="$(mktemp -d)"
trap 'rm -rf "$temporary"' EXIT
mkdir -p "$temporary/bin" "$temporary/state/dotpkg/wizard-test"
printf '#!/usr/bin/bash\nexit 0\n' > "$temporary/bin/frontend with spaces"
chmod +x "$temporary/bin/frontend with spaces"
cat > "$temporary/bin/kitty" <<'EOF'
#!/usr/bin/bash
printf '%s\n' "$@" > "$RESUME_TEST_ARGS"
EOF
chmod +x "$temporary/bin/kitty"
cat > "$temporary/state/dotpkg/wizard-test/resume.json" <<EOF
{"root":"$repo_root","args":["$temporary/bin/frontend with spaces","wizard","--resume","--manifest","$temporary/manifest with spaces.yaml"]}
EOF

# Command substitution keeps the output pipe open until the spawned stub exits.
output="$(PATH="$temporary/bin:$PATH" XDG_STATE_HOME="$temporary/state" \
  RESUME_TEST_ARGS="$temporary/args" bash "$repo_root/linux/install/resume")"
[ -z "$output" ]
cat > "$temporary/expected" <<EOF
--title
Finish machine setup
--
$temporary/bin/frontend with spaces
wizard
--resume
--manifest
$temporary/manifest with spaces.yaml
EOF
cmp "$temporary/expected" "$temporary/args"
printf 'graphical login continuation: ok\n'
