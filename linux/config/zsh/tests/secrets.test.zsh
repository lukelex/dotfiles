#!/usr/bin/env zsh
emulate -L zsh
setopt errexit
repo=${0:A:h:h:h:h:h}
temporary=$(mktemp -d)
trap 'rm -rf "$temporary"' EXIT
mkdir -p "$temporary/bin" "$temporary/refs"
export DOTFILES=$repo OPREFS_DIR="$temporary/refs"
export PATH="$temporary/bin:$PATH"
print -r -- 'TEST_SECRET=op://test/item/field' > "$OPREFS_DIR/secrets.env"
cat > "$temporary/bin/op" <<'EOF'
#!/usr/bin/bash
if [ "${SLOW_LOAD:-0}" = 1 ]; then sleep 10; fi
if [[ " $* " != *' --no-masking '* ]]; then
  printf 'TEST_SECRET\0<concealed by 1Password>\0'
  exit 0
fi
printf 'TEST_SECRET\0value with spaces\nand newline\n\0'
if [ "${FAIL_LOAD:-0}" = 1 ]; then
  echo 'sensitive resolver error' >&2
  exit 1
fi
EOF
chmod +x "$temporary/bin/op"
export FAIL_LOAD=1 TEST_SECRET=original
source "$repo/linux/config/zsh/secrets.zsh" 2> "$temporary/errors"
[[ $TEST_SECRET == original ]]
! grep -q sensitive "$temporary/errors"
grep -q secrets-retry "$temporary/errors"
export FAIL_LOAD=0
secrets-retry
[[ $TEST_SECRET == $'value with spaces\nand newline\n' ]]
export FAIL_LOAD=1
if secrets-retry 2>/dev/null; then
  print -ru2 -- 'Failed resolver incorrectly reported success'
  exit 1
fi
[[ $TEST_SECRET == $'value with spaces\nand newline\n' ]]
export FAIL_LOAD=0 SLOW_LOAD=1
if secrets-retry 2> "$temporary/errors"; then
  print -ru2 -- 'Timed-out resolver incorrectly reported success'
  exit 1
fi
grep -q 'timed out' "$temporary/errors"
[[ $TEST_SECRET == $'value with spaces\nand newline\n' ]]
print -- 'Secret loading tests passed'
