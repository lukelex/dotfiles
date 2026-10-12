const assert = require('node:assert/strict');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { test } = require('node:test');
const fs = require('node:fs');
const vm = require('node:vm');
const read = name => fs.readFileSync(path.join(__dirname, '..', name), 'utf8');

test('quick profile activation revalidates availability and preserves pending or dirty work', () => {
  const source = read('MonitorService.qml').match(/  function activateProfile\(name\) \{[^]*?\n  \}/)[0];
  const calls = [];
  const context = {
    busy: false, pending: false, dirty: false, error: '', draft: [{ connector: 'DP-1' }],
    snapshot: { session: 'x11', profiles: [{ name: 'desk', available: true, session: 'x11', current: false }] },
    chooseProfile: name => calls.push(['choose', name]), run: (...args) => calls.push(args),
  };
  const activate = vm.runInNewContext(`(${source})`, context);
  activate('desk');
  assert.deepEqual(calls, [['choose', 'desk'], ['apply', JSON.stringify(context.draft)]]);
  for (const flag of ['busy', 'pending', 'dirty']) {
    calls.length = 0;
    context[flag] = true;
    activate('desk');
    assert.equal(calls.length, 0);
    context[flag] = false;
  }
  for (const change of [{ available: false }, { session: 'wayland' }, { current: true }]) {
    context.snapshot.profiles[0] = { name: 'desk', available: true, session: 'x11', current: false, ...change };
    activate('desk');
    assert.equal(calls.length, 0);
  }
  activate('missing');
  assert.equal(calls.length, 0);
});

test('identify sends screen-specific labels to the shared OSD without creating windows', () => {
  const source = read('MonitorIdentify.qml');
  const calls = [];
  const identify = vm.runInNewContext(`(${source.match(/  function identify\(\) \{[^]*?\n  \}/)[0]})`, {
    Quickshell: { screens: [{ name: 'DP-1' }, { name: 'eDP-1' }, { name: 'new' }] },
    rootIdentify: { outputs: [{ connector: 'eDP-1' }, { connector: 'DP-1' }],
      controller: { notificationService: { showOsd: (...args) => calls.push(args) } } },
  });
  identify();
  assert.equal(calls[0][0], 'Monitor');
  assert.deepEqual(JSON.parse(JSON.stringify(calls[0][4])), { 'DP-1': '2 · DP-1', 'eDP-1': '1 · eDP-1', new: 'new' });
  assert.doesNotMatch(source, /PanelWindow|PopupWindow/);
});

test('monitor backend validates profiles, coordinates native adapters, and independently rolls back trials', () => {
  const result = spawnSync('python3', [path.resolve(__dirname, '../../system-settings/test_monitors.py')], {
    encoding: 'utf8', timeout: 30000, env: { ...process.env, PYTHONDONTWRITEBYTECODE: '1' },
  });
  assert.equal(result.status, 0, result.stdout + result.stderr);
});
