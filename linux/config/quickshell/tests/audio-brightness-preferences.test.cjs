const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { test } = require('node:test');
const { setTimeout: delay } = require('node:timers/promises');

const directory = path.resolve(__dirname, '../../system-settings');
function fixture(t) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'audio-brightness-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  fs.mkdirSync(path.join(root, 'bin'));
  fs.mkdirSync(path.join(root, 'dotfiles/linux'), { recursive: true });
  fs.writeFileSync(path.join(root, 'dotfiles/linux/variables.env'), 'LUCIDE_PATH=/icons\n');
  const file = path.join(root, 'preferences.json');
  const data = JSON.parse(fs.readFileSync(path.join(directory, 'preferences.json')));
  const save = () => fs.writeFileSync(file, JSON.stringify(data));
  save();
  for (const name of ['light', 'notify-send', 'u_keeb-backlight', 'u_monitors']) {
    fs.writeFileSync(path.join(root, 'bin', name), `#!/bin/sh\nprintf '%s\\n' '${name}' "$@" >> "$HOME/${name}.actions"\n`, { mode: 0o755 });
  }
  fs.writeFileSync(path.join(root, 'bin/wpctl'), `#!/bin/sh
if [ "$1" = get-volume ]; then echo "Volume: $(cat "$HOME/volume")"; else
  printf '%s\\n' "$@" >> "$HOME/wpctl.actions"
fi
`, { mode: 0o755 });
  fs.writeFileSync(path.join(root, 'bin/bc'), '#!/bin/sh\ncat > /dev/null\necho 0\n', { mode: 0o755 });
  fs.writeFileSync(path.join(root, 'volume'), '0.50');
  const env = { ...process.env, HOME: root, XDG_RUNTIME_DIR: root, DOTFILES_PREFERENCES: file,
    PATH: `${root}/bin:/usr/bin:/bin` };
  const run = (script, ...args) => {
    const result = spawnSync('bash', [path.resolve(directory, '../../scripts', script), ...args], { env, encoding: 'utf8' });
    assert.equal(result.status, 0, result.stderr);
    return result.stdout.trim();
  };
  const actions = name => fs.existsSync(path.join(root, `${name}.actions`)) ? fs.readFileSync(path.join(root, `${name}.actions`), 'utf8') : '';
  return { root, file, data, save, run, actions, env };
}

test('audio key steps default to 2% and customized increments retain the volume cap', t => {
  const f = fixture(t);
  f.run('audio', 'vol', 'inc');
  assert.match(f.actions('wpctl'), /set-volume\n-l\n1.0\n@DEFAULT_AUDIO_SINK@\n2%\+/);
  f.data.audio.volumeStep = 7;
  f.data.audio.microphoneStep = 9;
  f.save();
  f.run('audio', 'vol', 'inc');
  f.run('audio', 'vol', 'dec');
  f.run('audio', 'mic', 'inc');
  f.run('audio', 'mic', 'dec');
  assert.match(f.actions('wpctl'), /@DEFAULT_AUDIO_SINK@\n7%\+/);
  assert.match(f.actions('wpctl'), /@DEFAULT_AUDIO_SINK@\n7%-/);
  assert.match(f.actions('wpctl'), /@DEFAULT_AUDIO_SOURCE@\n59%/);
  assert.match(f.actions('wpctl'), /@DEFAULT_AUDIO_SOURCE@\n9%-/);
  fs.writeFileSync(path.join(f.root, 'volume'), '0.97');
  f.run('audio', 'mic', 'inc');
  assert.match(f.actions('wpctl'), /@DEFAULT_AUDIO_SOURCE@\n100%/);
});

test('brightness linking reads portable preferences and existing toggle persists without changing hardware', async t => {
  const f = fixture(t);
  f.data.display.linkBrightness = false;
  f.save();
  assert.equal(f.run('backlight', 'link-get'), 'false');
  f.run('backlight', 'set', '42');
  assert.equal(f.actions('u_monitors'), '');
  assert.equal(f.actions('u_keeb-backlight'), '');
  assert.equal(f.run('backlight', 'link-toggle'), 'true');
  assert.equal(JSON.parse(fs.readFileSync(f.file)).display.linkBrightness, true);
  assert.equal(f.actions('u_monitors'), '', 'enabling linking does not change brightness');
  f.run('backlight', 'set', '37');
  // Linking intentionally launches detached helpers. Wait for both mocks to
  // finish writing rather than racing the parent's successful exit.
  for (let attempt = 0; attempt < 100 && (!f.actions('u_monitors').includes('quiet') || !f.actions('u_keeb-backlight').includes('quiet')); attempt++)
    await delay(10);
  assert.match(f.actions('u_monitors'), /brightness\nset\n37\nquiet/);
  assert.match(f.actions('u_keeb-backlight'), /set\n37\nquiet/);
  assert.equal(f.run('backlight', 'link-toggle'), 'false');
  assert.equal(JSON.parse(fs.readFileSync(f.file)).display.linkBrightness, false);
});

test('audio, Bluetooth and brightness preferences reject invalid types and ranges', t => {
  const f = fixture(t);
  for (const [key, value] of [['audio.volumeStep', 0], ['audio.microphoneStep', 26],
    ['audio.volumeStep', 2.5], ['connectivity.bluetoothBatteryThreshold', 0],
    ['connectivity.bluetoothBatteryThreshold', 51], ['connectivity.bluetoothBatteryAlerts', 'true'],
    ['display.linkBrightness', 1]]) {
    const result = spawnSync('python3', [path.join(directory, 'settings.py'), 'set', key, JSON.stringify(value)], { env: f.env, encoding: 'utf8' });
    assert.notEqual(result.status, 0, key);
  }
  assert.deepEqual(JSON.parse(fs.readFileSync(f.file)), f.data);
});
