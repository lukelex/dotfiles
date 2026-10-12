const assert = require('node:assert/strict');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { test } = require('node:test');

test('monitor backend validates profiles, coordinates native adapters, and independently rolls back trials', () => {
  const result = spawnSync('python3', [path.resolve(__dirname, '../../system-settings/test_monitors.py')], {
    encoding: 'utf8', timeout: 30000, env: { ...process.env, PYTHONDONTWRITEBYTECODE: '1' },
  });
  assert.equal(result.status, 0, result.stdout + result.stderr);
});
