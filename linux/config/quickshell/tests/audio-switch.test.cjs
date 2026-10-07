const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { test } = require('node:test');

const helper = path.join(__dirname, '..', 'scripts', 'audio-switch');

function run(mode, failure) {
  const dir = fs.mkdtempSync('/tmp/opencode/audio-switch-');
  fs.writeFileSync(path.join(dir, 'pactl'), `#!/usr/bin/bash
printf '%s\n' "$*" >> "$TEST_DIR/calls"
case "$1" in
  set-default-*) [[ "$FAILURE" != default ]] ;;
  list)
    if [[ "$FAILURE" != vanished || ! -e "$TEST_DIR/moved" ]]; then
      printf '42\tdevice\tapplication\n'
    fi ;;
  move-*) touch "$TEST_DIR/moved"; [[ "$FAILURE" == none ]] ;;
esac
`);
  fs.chmodSync(path.join(dir, 'pactl'), 0o755);
  try {
    const result = spawnSync(helper, [mode, 'device with spaces'], {
      env: { ...process.env, PATH: `${dir}:${process.env.PATH}`, TEST_DIR: dir, FAILURE: failure },
      encoding: 'utf8',
    });
    return { status: result.status, calls: fs.readFileSync(path.join(dir, 'calls'), 'utf8') };
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
}

for (const mode of ['sink', 'source']) {
  test(`${mode} switching migrates streams and preserves device arguments`, () => {
    const result = run(mode, 'none');
    assert.equal(result.status, 0);
    assert.match(result.calls, new RegExp(`set-default-${mode} device with spaces`));
    assert.match(result.calls, new RegExp(`move-${mode === 'sink' ? 'sink-input' : 'source-output'} 42 device with spaces`));
  });
  test(`${mode} switching reports partial failure for a surviving stream`, () => {
    assert.equal(run(mode, 'move').status, 2);
  });
  test(`${mode} switching tolerates a stream ending during migration`, () => {
    assert.equal(run(mode, 'vanished').status, 0);
  });
  test(`${mode} switching does not migrate streams when setting the default fails`, () => {
    const result = run(mode, 'default');
    assert.equal(result.status, 1);
    assert.doesNotMatch(result.calls, /move-/);
  });
}
