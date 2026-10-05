const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { test } = require('node:test');

const config = path.resolve(__dirname, '../../gammastep');

test('sunset service does not parse shell variables as a systemd EnvironmentFile', () => {
  const unit = fs.readFileSync(path.join(config, 'night-mode-sunset.service'), 'utf8');
  assert.doesNotMatch(unit, /^EnvironmentFile=.*variables\.env/m);
});

for (const state of ['true', 'false', 'error']) {
  test(`sunset offer with helper state ${state}`, t => {
    const home = fs.mkdtempSync(path.join(os.tmpdir(), 'nightmode-test-'));
    t.after(() => fs.rmSync(home, { recursive: true, force: true }));
    const dotfiles = path.join(home, 'dotfiles');
    const bin = path.join(home, 'bin');
    const cache = path.join(home, 'cache');
    const runtime = path.join(home, 'run');
    const sent = path.join(home, 'sent');
    const helper = path.join(dotfiles, 'linux/config/quickshell/scripts/nightmode');
    fs.mkdirSync(path.dirname(helper), { recursive: true });
    for (const dir of [bin, runtime, path.join(cache, 'weather')])
      fs.mkdirSync(dir, { recursive: true });
    fs.writeFileSync(path.join(dotfiles, 'linux/variables.env'), 'DOTFILES="${DOTFILES:-$HOME/dotfiles}"\nLUCIDE_PATH="$DOTFILES/linux/config/lucide/svg"\n');
    fs.writeFileSync(helper, `#!/bin/bash\n${state === 'error' ? 'exit 1' : `echo ${state}`}\n`, { mode: 0o755 });
    fs.writeFileSync(path.join(bin, 'loginctl'), '#!/bin/bash\nexit 0\n', { mode: 0o755 });
    fs.writeFileSync(path.join(bin, 'pidof'), '#!/bin/bash\nexit 1\n', { mode: 0o755 });
    fs.writeFileSync(path.join(bin, 'notify-send'), '#!/bin/bash\necho sent > "$SENT"\necho 42 >&3\n', { mode: 0o755 });
    const now = Math.floor(Date.now() / 1000);
    fs.writeFileSync(path.join(cache, 'weather/current.json'), JSON.stringify({ sys: { sunrise: now - 3600, sunset: now - 60 } }));
    const env = { ...process.env, HOME: home, PATH: `${bin}:${process.env.PATH}`, XDG_CACHE_HOME: cache, XDG_STATE_HOME: path.join(home, 'state'), XDG_RUNTIME_DIR: runtime, SENT: sent };
    delete env.DOTFILES;
    const result = spawnSync('bash', [path.join(config, 'night-mode-sunset')], { env, encoding: 'utf8', timeout: 5000 });
    assert.equal(result.status, 0, result.stderr);
    assert.equal(fs.existsSync(sent), state === 'false');
    assert.equal(fs.existsSync(path.join(runtime, 'night-mode-sunset-notification-id')), false);
  });
}
