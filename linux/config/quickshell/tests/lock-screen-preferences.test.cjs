const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { test } = require('node:test');

const directory = path.resolve(__dirname, '../../system-settings');
const renderer = path.join(directory, 'lock-screen.py');
const template = fs.readFileSync(path.resolve(__dirname, '../../hypr/hyprlock.conf'), 'utf8')
  .replace('@LOCK_BRIGHTNESS@', '0.58');

function fixture(t) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'lock-screen-preferences-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  const file = path.join(root, 'preferences.json');
  const data = JSON.parse(fs.readFileSync(path.join(directory, 'preferences.json'), 'utf8'));
  const env = { ...process.env, DOTFILES_PREFERENCES: file, XDG_RUNTIME_DIR: root };
  const run = () => {
    fs.writeFileSync(file, JSON.stringify(data));
    const result = spawnSync('python3', [renderer], { env, input: template, encoding: 'utf8' });
    assert.equal(result.status, 0, result.stderr);
    return result.stdout;
  };
  return { file, data, env, run };
}

test('default lock preferences preserve existing widgets, authentication and wallpaper protection', t => {
  const f = fixture(t);
  const rendered = f.run();
  assert.match(rendered, /brightness = 0\.5800/);
  assert.match(rendered, /blur_size = 7/);
  assert.match(rendered, /lock-greeting/);
  assert.match(rendered, /lock-quote/);
  assert.match(rendered, /lock-media-art/);
  assert.match(rendered, /lock-battery-ring/);
  assert.match(rendered, /input-field \{/);
  assert.match(rendered, /# @FINGERPRINT_AUTH@/);
  assert.match(rendered, /text = \$TIME/);
  assert.match(rendered, /Session secured/);
});

test('each widget switch removes its helpers while leaving lock mechanics and notifications untouched', t => {
  const f = fixture(t);
  for (const key of Object.keys(f.data.lockScreen).filter(k => k.startsWith('show'))) f.data.lockScreen[key] = false;
  const rendered = f.run();
  assert.doesNotMatch(rendered, /linux\/scripts\/lock-(greeting|quote|status|media-art|battery-ring)/);
  assert.match(rendered, /lock-notifications/);
  assert.match(rendered, /text = \$TIME/);
  assert.match(rendered, /input-field \{/);
  assert.match(rendered, /hide_input = true/);
  assert.match(rendered, /# @FINGERPRINT_AUTH@/);
});

test('turning media text off also removes artwork, and artwork can be hidden independently', t => {
  const f = fixture(t);
  f.data.lockScreen.showMedia = false;
  let rendered = f.run();
  assert.doesNotMatch(rendered, /lock-media-art|lock-status" media/);
  f.data.lockScreen.showMedia = true;
  f.data.lockScreen.showMediaArtwork = false;
  rendered = f.run();
  assert.doesNotMatch(rendered, /lock-media-art/);
  assert.match(rendered, /lock-status" media/);
});

test('wallpaper presentation settings do not alter authentication or tint', t => {
  const f = fixture(t);
  f.data.lockScreen.wallpaperBlur = 12;
  f.data.lockScreen.wallpaperBlurPasses = 0;
  f.data.lockScreen.wallpaperBrightness = 39;
  const rendered = f.run();
  assert.match(rendered, /blur_size = 12/);
  assert.match(rendered, /blur_passes = 0/);
  assert.match(rendered, /brightness = 0\.2900/);
  assert.match(rendered, /color = rgba\(43, 48, 58, 0\.78\)/);
  assert.match(rendered, /hide_input = true/);
});

test('invalid preferences fall back to safe defaults rather than blocking locking', t => {
  const f = fixture(t);
  fs.writeFileSync(f.file, '{broken');
  const result = spawnSync('python3', [renderer], { env: f.env, input: template, encoding: 'utf8' });
  assert.equal(result.status, 0);
  assert.match(result.stderr, /using defaults/);
  assert.match(result.stdout, /input-field \{/);
  assert.match(result.stdout, /blur_size = 7/);
});
