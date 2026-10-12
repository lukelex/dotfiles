const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync, spawn } = require('node:child_process');
const { test } = require('node:test');

const directory = path.resolve(__dirname, '../../system-settings');
const helper = path.join(directory, 'settings.py');

function fixture(t, session = 'x11') {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'system-preferences-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  const file = path.join(root, 'preferences.json');
  fs.copyFileSync(path.join(directory, 'preferences.json'), file);
  const bin = path.join(root, 'bin');
  fs.mkdirSync(bin);
  for (const command of ['xset', 'hyprctl', 'systemctl', 'gammastep', 'hypridle', 'xautolock', 'u_autolocking']) {
    fs.writeFileSync(path.join(bin, command), `#!/bin/sh\nprintf '%s\\n' '${command}' "$@" >> "$HOME/commands"\n`, { mode: 0o755 });
  }
  const env = { ...process.env, HOME: root, XDG_CACHE_HOME: path.join(root, 'cache'),
    XDG_RUNTIME_DIR: root, XDG_SESSION_TYPE: session, DOTFILES_PREFERENCES: file, PATH: `${bin}:/usr/bin:/bin` };
  const run = (...args) => spawnSync('python3', [helper, ...args], { env, encoding: 'utf8' });
  const data = () => JSON.parse(fs.readFileSync(file, 'utf8'));
  return { root, file, env, run, data };
}

test('preferences are clone-portable and contain no history or transient DND override', t => {
  const f = fixture(t);
  assert.equal(f.run('validate').status, 0);
  const described = JSON.parse(f.run('describe').stdout);
  assert.ok(described.fields.length >= 30);
  assert.equal(described.data.input.repeatRate, 35);
  assert.equal(described.data.notifications.historyRetentionDays, 7);
  assert.ok(!JSON.stringify(described).includes('historyJson'));
  assert.ok(!JSON.stringify(described).includes('dndOverrideUntil'));
});

test('invalid edits are rejected atomically and preserve every existing preference', t => {
  const f = fixture(t);
  const original = fs.readFileSync(f.file, 'utf8');
  for (const [key, value] of [['input.repeatDelay', -1], ['input.repeatRate', 1.5],
    ['idle.x11LockSeconds', 65], ['display.latitude', 91], ['desktop.hoverPreviews', 'true'],
    ['clock.hourFormat', 12], ['weather.units', 'kelvin'], ['notifications.popupDurationSeconds', 3],
    ['notifications.applications', [{ appName: 'Broken' }]], ['input.unknown', true]]) {
    assert.notEqual(f.run('set', key, JSON.stringify(value)).status, 0, key);
    assert.equal(fs.readFileSync(f.file, 'utf8'), original);
  }
  assert.notEqual(f.run('patch', '{"input.repeatRate":20,"input.repeatDelay":-1}').status, 0);
  assert.equal(fs.readFileSync(f.file, 'utf8'), original);
});

test('simultaneous writers merge keys without losing preferences', async t => {
  const f = fixture(t);
  const entries = [['clock.firstDay', 0], ['weather.units', 'imperial'], ['input.repeatRate', 40], ['display.brightnessStep', 10]];
  await Promise.all(entries.map(([key, value]) => new Promise((resolve, reject) => {
    const process = spawn('python3', [helper, 'set', key, JSON.stringify(value)], { env: f.env });
    process.on('error', reject);
    process.on('exit', code => code === 0 ? resolve() : reject(new Error(`writer failed: ${code}`)));
  })));
  for (const [key, value] of entries) {
    const [section, name] = key.split('.');
    assert.equal(f.data()[section][name], value);
  }
  assert.equal(f.data().notifications.historyRetentionDays, 7);
});

test('X11 applies repeat preferences and launches its existing idle backend with saved times', t => {
  const f = fixture(t);
  assert.equal(f.run('patch', '{"input.repeatDelay":500,"input.repeatRate":25,"idle.x11LockSeconds":420,"idle.x11ScreenOffSeconds":900}').status, 0);
  assert.equal(f.run('apply', 'input').status, 0);
  assert.equal(f.run('run-idle').status, 0);
  const commands = fs.readFileSync(path.join(f.root, 'commands'), 'utf8');
  assert.match(commands, /xset\nr\nrate\n500\n25/);
  assert.match(commands, /dpms\n900\n0\n0/);
  assert.match(commands, /xautolock\n-time\n7/);
});

test('Hyprland input and generated idle config use saved values, with disabled timers omitted', t => {
  const f = fixture(t, 'wayland');
  assert.equal(f.run('patch', '{"input.sensitivity":-0.2,"input.tapToClick":false,"idle.dimSeconds":0,"idle.lockSeconds":600,"idle.screenOffSeconds":900}').status, 0);
  assert.equal(f.run('apply', 'input').status, 0);
  assert.equal(f.run('run-idle').status, 0);
  const commands = fs.readFileSync(path.join(f.root, 'commands'), 'utf8');
  assert.match(commands, /input:sensitivity\n-0.2/);
  assert.match(commands, /input:touchpad:tap-to-click\nfalse/);
  const config = fs.readFileSync(path.join(f.root, 'cache/dotfiles/settings/hypridle.conf'), 'utf8');
  assert.doesNotMatch(config, /u_backlight dim/);
  assert.match(config, /timeout = 540/);
  assert.match(config, /timeout = 590/);
  assert.match(config, /timeout = 600/);
  assert.match(config, /timeout = 900/);
  assert.match(config, /before_sleep_cmd = u_lock-before-sleep/);
});

test('night-light startup renders temperature and coordinates from the portable store', t => {
  const f = fixture(t);
  assert.equal(f.run('patch', '{"display.nightTemperature":3200,"display.latitude":-33.9,"display.longitude":151.2}').status, 0);
  assert.equal(f.run('run-night-light').status, 0);
  const config = fs.readFileSync(path.join(f.root, 'cache/dotfiles/settings/gammastep.ini'), 'utf8');
  assert.match(config, /temp-night=3200/);
  assert.match(config, /lat=-33.9/);
  assert.match(config, /lon=151.2/);
});

test('changing idle policy clears a deferred lock before restarting the idle backend', t => {
  const f = fixture(t);
  assert.equal(f.run('apply', 'idle').status, 0);
  const commands = fs.readFileSync(path.join(f.root, 'commands'), 'utf8');
  assert.match(commands, /^u_autolocking\nclear-warning\nsystemctl\n--user\ndaemon-reload\nsystemctl\n--user\ntry-restart\nxautolock.service/);
});
