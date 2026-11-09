const assert = require('node:assert/strict');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { test } = require('node:test');

test('Bluetooth pairing lifecycle and private D-Bus transport', () => {
  const result = spawnSync('python3', ['-B', path.join(__dirname, 'bluetooth-agent.test.py')], {
    encoding: 'utf8', timeout: 30000,
  });
  assert.equal(result.status, 0, result.stderr || result.error?.message);
});
