const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { test } = require('node:test');

const directory = path.resolve(__dirname, '../../system-settings');
function fixture(t) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'wallpaper-power-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  fs.mkdirSync(path.join(root, 'bin'));
  fs.mkdirSync(path.join(root, 'dotfiles/linux'), { recursive: true });
  fs.writeFileSync(path.join(root, 'dotfiles/linux/variables.env'), 'LUCIDE_PATH=/icons\n');
  const file = path.join(root, 'preferences.json');
  const data = JSON.parse(fs.readFileSync(path.join(directory, 'preferences.json')));
  fs.writeFileSync(file, JSON.stringify(data));
  for (const name of ['xwallpaper', 'awww', 'notify-send']) {
    fs.writeFileSync(path.join(root, 'bin', name), `#!/bin/sh\nprintf '%s\\n' '${name}' "$@" >> "$HOME/actions"\n`, { mode: 0o755 });
  }
  fs.writeFileSync(path.join(root, 'bin/upower'), `#!/bin/sh
if [ "$1" = -e ]; then echo /battery/BAT0; else
  echo "state: $(cat "$HOME/state")"
  echo "percentage: $(cat "$HOME/charge")%"
fi
`, { mode: 0o755 });
  fs.writeFileSync(path.join(root, 'bin/busctl'), '#!/bin/sh\nexit 0\n', { mode: 0o755 });
  const env = { ...process.env, HOME: root, XDG_CACHE_HOME: path.join(root, 'cache'),
    XDG_RUNTIME_DIR: root, DOTFILES_PREFERENCES: file, XDG_SESSION_TYPE: 'x11', PATH: `${root}/bin:/usr/bin:/bin` };
  const save = () => fs.writeFileSync(file, JSON.stringify(data));
  const run = (script, ...args) => spawnSync('python3', [path.join(directory, script), ...args], { env, encoding: 'utf8' });
  const actions = () => fs.existsSync(path.join(root, 'actions')) ? fs.readFileSync(path.join(root, 'actions'), 'utf8') : '';
  return { root, file, data, save, env, run, actions };
}

test('wallpaper folder choices ignore non-images and startup restore uses the saved wallpaper', t => {
  const f = fixture(t);
  const folder = path.join(f.root, 'images with spaces');
  fs.mkdirSync(folder);
  fs.writeFileSync(path.join(folder, 'one.jpg'), 'image bytes');
  fs.writeFileSync(path.join(folder, 'notes.txt'), 'not an image');
  f.data.wallpaper.folder = '~/images with spaces';
  f.save();
  assert.equal(f.run('wallpaper.py', 'startup').status, 0);
  assert.equal(fs.readFileSync(path.join(f.root, 'wallpaper.png'), 'utf8'), 'image bytes');
  assert.match(f.actions(), /xwallpaper\n--zoom/);
  f.data.wallpaper.startupMode = 'restore';
  f.data.wallpaper.folder = '/does/not/exist';
  f.save();
  assert.equal(f.run('wallpaper.py', 'startup').status, 0);
  assert.notEqual(f.run('wallpaper.py', 'random').status, 0);
});

test('wallpaper file picker URLs decode safely and Wayland uses the existing native backend', t => {
  const f = fixture(t);
  const image = path.join(f.root, 'my photo.png');
  fs.writeFileSync(image, 'photo');
  f.env.XDG_SESSION_TYPE = 'wayland';
  assert.equal(f.run('wallpaper.py', 'choose', `file://${image.replace(/ /g, '%20')}`).status, 0);
  assert.match(f.actions(), /awww\nimg/);
  assert.notEqual(f.run('wallpaper.py', 'choose', 'file://remote/photo.png').status, 0);
});

test('battery preferences suppress individual levels and retain once-per-episode markers', t => {
  const f = fixture(t);
  f.data.power = { lowWarningEnabled: true, lowThreshold: 25, criticalWarningEnabled: true,
    criticalThreshold: 20, urgentWarningEnabled: false, urgentThreshold: 10, finalWarningEnabled: true, finalThreshold: 5 };
  f.save();
  const script = path.resolve(__dirname, '../scripts/battery');
  const warn = (charge, state = 'discharging') => {
    fs.writeFileSync(path.join(f.root, 'charge'), String(charge));
    fs.writeFileSync(path.join(f.root, 'state'), state);
    const result = spawnSync('bash', [script, 'warn'], { env: f.env, encoding: 'utf8' });
    assert.equal(result.status, 0, result.stderr);
  };
  const count = () => (f.actions().match(/^notify-send$/gm) || []).length;
  warn(25); warn(25);
  assert.equal(count(), 1);
  warn(20); warn(20); warn(10);
  assert.equal(count(), 2, 'disabled urgent warning does not fire');
  warn(5); warn(5);
  assert.equal(count(), 3);
  warn(50, 'charging'); warn(20);
  assert.equal(count(), 4, 'charging rearms discharge warnings');
  f.data.power.criticalWarningEnabled = false;
  f.data.power.finalWarningEnabled = false;
  f.data.power.lowWarningEnabled = false;
  f.save();
  warn(50, 'charging'); warn(5);
  assert.equal(count(), 4, 'all warning levels can be disabled');
});

test('policy validation rejects inverted battery thresholds and invalid Wi-Fi hysteresis atomically', t => {
  const f = fixture(t);
  const original = fs.readFileSync(f.file, 'utf8');
  for (const [key, value] of [['power.finalThreshold', 20], ['connectivity.recoveryThreshold', 20],
    ['connectivity.minimumImprovement', 0], ['wallpaper.startupMode', 'slideshow']]) {
    assert.notEqual(f.run('settings.py', 'set', key, JSON.stringify(value)).status, 0);
    assert.equal(fs.readFileSync(f.file, 'utf8'), original);
  }
});

test('failed wallpaper backend preserves the previously saved image', t => {
  const f = fixture(t);
  fs.writeFileSync(path.join(f.root, 'wallpaper.png'), 'previous');
  const candidate = path.join(f.root, 'candidate.jpg');
  fs.writeFileSync(candidate, 'candidate');
  fs.writeFileSync(path.join(f.root, 'bin/xwallpaper'), '#!/bin/sh\necho "Image rejected" >&2\nexit 1\n', { mode: 0o755 });
  assert.notEqual(f.run('wallpaper.py', 'choose', candidate).status, 0);
  assert.equal(fs.readFileSync(path.join(f.root, 'wallpaper.png'), 'utf8'), 'previous');
});
