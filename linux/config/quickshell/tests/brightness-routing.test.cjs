const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { execFileSync } = require('node:child_process');
const { test } = require('node:test');

const helper = path.join(__dirname, '..', 'scripts', 'brightness');

function run(external, args) {
  const home = fs.mkdtempSync(path.join(os.tmpdir(), 'quickshell-brightness-'));
  const scripts = path.join(home, 'dotfiles', 'linux', 'scripts');
  fs.mkdirSync(scripts, { recursive: true });
  fs.writeFileSync(path.join(scripts, 'monitors'), `#!/usr/bin/bash\nif [[ "$2" == if ]]; then printf '%s\\n' "${external}"; else printf 'monitor:%s\\n' "$*"; fi\n`);
  fs.writeFileSync(path.join(scripts, 'backlight'), '#!/usr/bin/bash\nprintf \'backlight:%s\\n\' "$*"\n');
  fs.chmodSync(path.join(scripts, 'monitors'), 0o755);
  fs.chmodSync(path.join(scripts, 'backlight'), 0o755);
  try {
    return execFileSync(helper, args, { encoding: 'utf8', env: { ...process.env, HOME: home } }).trim();
  } finally {
    fs.rmSync(home, { recursive: true, force: true });
  }
}

test('brightness helper uses DDC controls when an external display is available', () => {
  assert.equal(run('true', ['set', '60']), 'monitor:brightness set 60');
});

test('brightness helper falls back to the internal backlight without an external display', () => {
  assert.equal(run('false', ['get']), 'backlight:get');
});
