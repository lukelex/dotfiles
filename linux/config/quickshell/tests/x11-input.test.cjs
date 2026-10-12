const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

test('X11 input targets supported device properties and reports failures', () => {
  const result = spawnSync('python3', ['-m', 'unittest', 'test_x11_input.py'], {
    cwd: path.resolve(__dirname, '../../system-settings'), encoding: 'utf8',
  });
  assert.equal(result.status, 0, result.stdout + result.stderr);
});
