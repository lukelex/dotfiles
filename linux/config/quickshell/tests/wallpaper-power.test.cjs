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

test('wallpaper folder writes normalize shell-escaped spaces and home paths', t => {
  const f = fixture(t);
  for (const command of ['set', 'patch']) {
    const folder = `${f.root}/SeaDrive/My\\ Libraries/My\\ Library/wallpapers`;
    const args = command === 'set'
      ? ['wallpaper.folder', JSON.stringify(folder)]
      : [JSON.stringify({ 'wallpaper.folder': folder })];
    const result = f.run('settings.py', command, ...args);
    assert.equal(result.status, 0, result.stderr);
    assert.equal(JSON.parse(fs.readFileSync(f.file)).wallpaper.folder,
      '~/SeaDrive/My Libraries/My Library/wallpapers');
  }
  const result = f.run('settings.py', 'set', 'wallpaper.folder', JSON.stringify('~/images with spaces'));
  assert.equal(result.status, 0, result.stderr);
  assert.equal(JSON.parse(fs.readFileSync(f.file)).wallpaper.folder, '~/images with spaces');
});

test('wallpaper folder choices ignore non-images and startup restore uses the saved wallpaper', t => {
  const f = fixture(t);
  const folder = path.join(f.root, 'images with spaces');
  const nested = path.join(folder, 'landscapes', 'favorites', '2026');
  fs.mkdirSync(nested, { recursive: true });
  fs.writeFileSync(path.join(nested, 'one.jpg'), 'image bytes');
  fs.writeFileSync(path.join(nested, 'notes.txt'), 'not an image');
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
  const chosen = f.run('wallpaper.py', 'choose', `file://${image.replace(/ /g, '%20')}`);
  assert.equal(chosen.status, 0);
  assert.equal(chosen.stdout.trim(), image);
  assert.match(f.actions(), /awww\nimg/);
  assert.notEqual(f.run('wallpaper.py', 'choose', 'file://remote/photo.png').status, 0);
});

test('random wallpaper prefers images large enough and close to the active display aspect ratio', t => {
  const f = fixture(t);
  const folder = path.join(f.root, 'images');
  fs.mkdirSync(folder);
  const nested = path.join(folder, 'landscapes', 'ultrawide');
  fs.mkdirSync(nested, { recursive: true });
  fs.writeFileSync(path.join(nested, 'wide.jpg'), 'wide.jpg');
  for (const name of ['bad.jpg', 'small.jpg', 'tall.jpg', 'notes.txt']) {
    fs.writeFileSync(path.join(folder, name), name);
  }
  fs.writeFileSync(path.join(f.root, 'bin/hyprctl'), `#!/bin/sh
echo '[{"width":1920,"height":1080,"focused":false},{"width":3440,"height":1440,"focused":true}]'
`, { mode: 0o755 });
  fs.writeFileSync(path.join(f.root, 'bin/magick'), `#!/bin/sh
echo call >> "$HOME/identify-calls"
shift 4
status=0
for image do
  name=$(printf '%s' "$image" | sed 's/\\[0\\]$//')
  case "$image" in
    */wide.jpg\\[0\\]) printf '%s\\t3840 1600\\n' "$name" ;;
    */small.jpg\\[0\\]) printf '%s\\t1920 800\\n' "$name" ;;
    */tall.jpg\\[0\\]) printf '%s\\t3840 2160\\n' "$name" ;;
    */bad.jpg\\[0\\]) status=1 ;;
  esac
done
exit "$status"
`, { mode: 0o755 });
  f.env.XDG_SESSION_TYPE = 'wayland';
  const selected = f.run('wallpaper.py', 'random', folder);
  assert.equal(selected.status, 0);
  assert.equal(selected.stdout.trim(), path.join(nested, 'wide.jpg'));
  assert.equal(fs.readFileSync(path.join(f.root, 'wallpaper.png'), 'utf8'), 'wide.jpg');
  assert.equal(fs.readFileSync(path.join(f.root, 'identify-calls'), 'utf8'), 'call\n', 'one identify process for the pool');
  fs.unlinkSync(path.join(nested, 'wide.jpg'));
  fs.unlinkSync(path.join(folder, 'small.jpg'));
  fs.unlinkSync(path.join(folder, 'bad.jpg'));
  assert.equal(f.run('wallpaper.py', 'random', folder).status, 0);
  assert.equal(fs.readFileSync(path.join(f.root, 'wallpaper.png'), 'utf8'), 'tall.jpg', 'falls back to all images');
});

test('random wallpaper uses the primary X11 monitor and falls back if resolution is unavailable', t => {
  const f = fixture(t);
  const folder = path.join(f.root, 'images');
  fs.mkdirSync(folder);
  fs.writeFileSync(path.join(folder, 'wide.jpg'), 'wide');
  fs.writeFileSync(path.join(folder, 'normal.jpg'), 'normal');
  fs.writeFileSync(path.join(f.root, 'bin/xrandr'), `#!/bin/sh
echo 'HDMI-1 connected 3440x1440+0+0'
echo 'eDP-1 connected primary 1920x1080+3440+0'
`, { mode: 0o755 });
  fs.writeFileSync(path.join(f.root, 'bin/magick'), `#!/bin/sh
shift 4
for image do
  name=$(printf '%s' "$image" | sed 's/\\[0\\]$//')
  case "$image" in
    */wide.jpg\\[0\\]) printf '%s\\t3840 1600\\n' "$name" ;;
    */normal.jpg\\[0\\]) printf '%s\\t2560 1440\\n' "$name" ;;
  esac
done
`, { mode: 0o755 });
  assert.equal(f.run('wallpaper.py', 'random', folder).status, 0);
  assert.equal(fs.readFileSync(path.join(f.root, 'wallpaper.png'), 'utf8'), 'normal');
  fs.unlinkSync(path.join(f.root, 'bin/xrandr'));
  assert.equal(f.run('wallpaper.py', 'random', folder).status, 0);
  assert.equal(fs.readFileSync(path.join(f.root, 'wallpaper.png'), 'utf8'), 'wide', 'tries remaining images if the matching one is current');
  fs.unlinkSync(path.join(folder, 'wide.jpg'));
  assert.equal(f.run('wallpaper.py', 'random', folder).status, 0);
  assert.equal(fs.readFileSync(path.join(f.root, 'wallpaper.png'), 'utf8'), 'normal');
});

test('random wallpaper never reapplies the current image, even from a duplicate file', t => {
  const f = fixture(t);
  const folder = path.join(f.root, 'images');
  fs.mkdirSync(path.join(folder, 'nested'), { recursive: true });
  fs.writeFileSync(path.join(folder, 'original.jpg'), 'current image');
  fs.writeFileSync(path.join(folder, 'nested', 'duplicate.jpg'), 'current image');
  fs.writeFileSync(path.join(folder, 'different.jpg'), 'new image');
  assert.equal(f.run('wallpaper.py', 'choose', path.join(folder, 'original.jpg')).status, 0);
  assert.equal(f.run('wallpaper.py', 'random', folder).status, 0);
  assert.equal(fs.readFileSync(path.join(f.root, 'wallpaper.png'), 'utf8'), 'new image');
  fs.unlinkSync(path.join(folder, 'different.jpg'));
  const actions = f.actions();
  const result = f.run('wallpaper.py', 'random', folder);
  assert.equal(result.status, 0, result.stderr);
  assert.equal(fs.readFileSync(path.join(f.root, 'wallpaper.png'), 'utf8'), 'current image');
  assert.notEqual(f.actions(), actions);
  const applied = f.actions();
  const noAlternative = f.run('wallpaper.py', 'random', folder);
  assert.notEqual(noAlternative.status, 0);
  assert.match(noAlternative.stderr, /No different wallpaper/);
  assert.equal(f.actions(), applied, 'no wallpaper backend call for identical images');
});

test('random wallpaper skips intermittent source read failures without hiding explicit or local errors', t => {
  const f = fixture(t);
  const folder = path.join(f.root, 'images');
  fs.mkdirSync(folder);
  fs.writeFileSync(path.join(folder, 'a-broken.jpg'), 'unavailable');
  fs.writeFileSync(path.join(folder, 'b-good.jpg'), 'good');
  const result = spawnSync('python3', ['-c', `
import errno
from pathlib import Path
import shutil
import wallpaper

folder = Path.home() / 'images'
wallpaper.screen_size = lambda: None
wallpaper.random.shuffle = lambda candidates: candidates.sort()
copyfile = shutil.copyfile

def fail_source(source, destination):
  if str(source).endswith('a-broken.jpg'):
    raise OSError(errno.EIO, 'SeaDrive read failed', str(source), str(destination))
  return copyfile(source, destination)

shutil.copyfile = fail_source
wallpaper.random_wallpaper(str(folder))
assert (Path.home() / 'wallpaper.png').read_text() == 'good'
try:
  wallpaper.choose(folder / 'a-broken.jpg')
except OSError as error:
  assert error.errno == errno.EIO
else:
  raise AssertionError('explicit choice must report source failure')

def fail_destination(source, destination):
  raise OSError(errno.EIO, 'local write failed', str(destination))

shutil.copyfile = fail_destination
try:
  wallpaper.random_wallpaper(str(folder))
except OSError as error:
  assert error.filename != str(folder / 'a-broken.jpg')
else:
  raise AssertionError('local write failure must not be skipped')
assert (Path.home() / 'wallpaper.png').read_text() == 'good'
`], { env: { ...f.env, PYTHONPATH: directory }, encoding: 'utf8' });
  assert.equal(result.status, 0, result.stderr);
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
