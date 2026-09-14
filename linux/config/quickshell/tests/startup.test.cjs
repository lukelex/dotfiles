const assert = require('node:assert/strict');
const fs = require('node:fs');
const net = require('node:net');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { test } = require('node:test');

const launcher = path.resolve(__dirname, '../scripts/quickshell');

async function fixture(t) {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'qs-startup-'));
  const socket = path.join(directory, 'i3.sock');
  const hyprland = {
    runtime: path.join(directory, 'runtime'),
    signature: 'hypr-test',
  };
  const hyprlandDirectory = path.join(hyprland.runtime, 'hypr', hyprland.signature);
  const servers = [net.createServer(), net.createServer(), net.createServer()];
  t.after(async () => {
    await Promise.all(servers.filter(server => server.listening)
      .map(server => new Promise(resolve => server.close(resolve))));
    fs.rmSync(directory, { recursive: true, force: true });
  });
  fs.mkdirSync(hyprlandDirectory, { recursive: true });
  await Promise.all([
    [servers[0], socket],
    [servers[1], path.join(hyprlandDirectory, '.socket.sock')],
    [servers[2], path.join(hyprlandDirectory, '.socket2.sock')],
  ].map(([server, path]) => new Promise((resolve, reject) => {
    server.once('error', reject);
    server.listen(path, resolve);
  })));
  assert.ok(fs.statSync(socket).isSocket());

  const bin = path.join(directory, 'bin');
  const home = path.join(directory, 'fake home');
  const log = path.join(directory, 'calls.jsonl');
  fs.mkdirSync(bin);
  fs.mkdirSync(home);
  fs.writeFileSync(log, '');
  const mock = `#!${process.execPath}
const fs = require('node:fs');
const path = require('node:path');
const command = path.basename(process.argv[1]);
const args = process.argv.slice(2);
fs.appendFileSync(process.env.CALL_LOG, JSON.stringify({
  command, args, env: process.env, pid: process.pid,
}) + '\\n');
if (command === 'i3') {
  process.stdout.write(process.env.DISCOVER_SOCKET || '');
  process.exit(Number(process.env.DISCOVER_STATUS || 0));
}
if (command === 'systemctl' && args[1] === 'import-environment') {
  process.exit(Number(process.env.IMPORT_STATUS || 0));
}
if (command === 'quickshell') process.exit(Number(process.env.LAUNCH_STATUS || 0));
if (command === 'sleep') process.exit(99);
`;
  for (const command of ['i3', 'systemctl', 'quickshell', 'sleep']) {
    fs.writeFileSync(path.join(bin, command), mock, { mode: 0o755 });
  }

  return {
    socket,
    hyprland,
    home,
    directory,
    run(args = [], overrides = {}) {
      // Do not inherit login credentials, BASH_ENV, or the real command search path.
      const env = {
        PATH: bin,
        HOME: home,
        DISPLAY: ':987',
        I3SOCK: socket,
        CALL_LOG: log,
        DISCOVER_SOCKET: socket,
        ...overrides,
      };
      for (const name of Object.keys(env)) {
        if (env[name] === undefined) delete env[name];
      }
      fs.writeFileSync(log, '');
      const result = spawnSync('/usr/bin/bash', ['--noprofile', '--norc', launcher, ...args], {
        cwd: directory,
        env,
        encoding: 'utf8',
        timeout: 2000,
        killSignal: 'SIGKILL',
      });
      assert.ifError(result.error);
      assert.equal(result.signal, null, result.stderr);
      const calls = fs.readFileSync(log, 'utf8').trim().split('\n').filter(Boolean).map(JSON.parse);
      return { ...result, calls };
    },
  };
}

function commands(result) {
  return result.calls.map(({ command, args }) => [command, ...args]);
}

for (const args of [[], ['--session-start']]) {
  test(`missing DISPLAY fails before discovery, retries, or launch (${args[0] || 'default'})`, async t => {
    const f = await fixture(t);
    for (const DISPLAY of [undefined, '']) {
      const result = f.run(args, { DISPLAY, I3SOCK: undefined });
      assert.equal(result.status, 1);
      assert.match(result.stderr, /active i3 or Hyprland session/);
      assert.deepEqual(result.calls, []);
    }
  });
}

test('valid socket execs the default shell with the HOME config and verbatim arguments', async t => {
  const f = await fixture(t);
  const forwarded = ['--verbose', 'argument with spaces', '', 'literal;$HOME'];
  const result = f.run(forwarded, { LAUNCH_STATUS: '23' });
  assert.equal(result.status, 23);
  assert.deepEqual(commands(result), [
    ['quickshell', '--path', path.join(f.home, 'dotfiles/linux/config/quickshell/shell.qml'), ...forwarded],
  ]);
  assert.equal(result.calls[0].pid, result.pid, 'quickshell must replace Bash via exec');
  assert.equal(result.calls[0].env.DISPLAY, ':987');
  assert.equal(result.calls[0].env.I3SOCK, f.socket);
  assert.equal(result.calls[0].env.HOME, f.home);
});

for (const state of ['missing', 'stale', 'regular file']) {
  test(`${state} I3SOCK is discovered exactly once and exported`, async t => {
    const f = await fixture(t);
    const invalid = path.join(f.directory, 'not-a-socket');
    if (state === 'regular file') fs.writeFileSync(invalid, 'not a socket');
    const result = f.run([], { I3SOCK: state === 'missing' ? undefined : invalid });
    assert.equal(result.status, 0, result.stderr);
    assert.deepEqual(commands(result), [
      ['i3', '--get-socketpath'],
      ['quickshell', '--path', path.join(f.home, 'dotfiles/linux/config/quickshell/shell.qml')],
    ]);
    assert.equal(result.calls[1].env.I3SOCK, f.socket);
  });
}

for (const failure of ['nonzero', 'empty', 'stale', 'regular file']) {
  test(`discovery ${failure} exits within two seconds without retries or startup`, async t => {
    const f = await fixture(t);
    const invalid = path.join(f.directory, 'invalid-discovered-socket');
    if (failure === 'regular file') fs.writeFileSync(invalid, 'not a socket');
    for (const args of [[], ['--session-start']]) {
      const result = f.run(args, {
        I3SOCK: undefined,
        DISCOVER_STATUS: failure === 'nonzero' ? '1' : '0',
        DISCOVER_SOCKET: failure === 'nonzero' ? f.socket : failure === 'empty' ? '' : invalid,
      });
      assert.equal(result.status, 1);
      assert.match(result.stderr, /no ready i3 IPC socket/);
      assert.deepEqual(commands(result), [['i3', '--get-socketpath']]);
    }
  });
}

test('session startup imports only session names before idempotent start, never restart', async t => {
  const f = await fixture(t);
  const XAUTHORITY = path.join(f.home, 'fake Xauthority');
  for (let attempt = 0; attempt < 2; attempt++) {
    const result = f.run(['--session-start'], {
      XAUTHORITY,
      OPEN_WEATHER_API_KEY: 'synthetic-weather-value',
      AWS_SECRET_ACCESS_KEY: 'synthetic-aws-value',
      GITHUB_TOKEN: 'synthetic-github-value',
    });
    assert.equal(result.status, 0, result.stderr);
    assert.deepEqual(commands(result), [
      ['systemctl', '--user', 'unset-environment', 'HYPRLAND_INSTANCE_SIGNATURE', 'WAYLAND_DISPLAY'],
      ['systemctl', '--user', 'import-environment', 'DISPLAY', 'I3SOCK', 'XAUTHORITY'],
      ['systemctl', '--user', 'start', 'quickshell.service'],
    ]);
    for (const call of result.calls) {
      assert.equal(call.env.DISPLAY, ':987');
      assert.equal(call.env.I3SOCK, f.socket);
      assert.equal(call.env.XAUTHORITY, XAUTHORITY);
    }
    assert.equal(result.calls[2].pid, result.pid, 'systemctl start must replace Bash');
  }
});

test('unset or empty XAUTHORITY clears the manager value before importing the discovered session', async t => {
  const f = await fixture(t);
  for (const XAUTHORITY of [undefined, '']) {
    const result = f.run(['--session-start'], { I3SOCK: undefined, XAUTHORITY });
    assert.equal(result.status, 0, result.stderr);
    assert.deepEqual(commands(result), [
      ['i3', '--get-socketpath'],
      ['systemctl', '--user', 'unset-environment', 'HYPRLAND_INSTANCE_SIGNATURE', 'WAYLAND_DISPLAY'],
      ['systemctl', '--user', 'unset-environment', 'XAUTHORITY'],
      ['systemctl', '--user', 'import-environment', 'DISPLAY', 'I3SOCK'],
      ['systemctl', '--user', 'start', 'quickshell.service'],
    ]);
    assert.equal(result.calls[2].env.I3SOCK, f.socket);
    assert.equal(result.calls[2].env.XAUTHORITY, XAUTHORITY);
  }
});

test('failed environment import blocks service startup', async t => {
  const f = await fixture(t);
  for (const XAUTHORITY of [undefined, path.join(f.home, 'fake Xauthority')]) {
    const result = f.run(['--session-start'], { XAUTHORITY, IMPORT_STATUS: '42' });
    assert.equal(result.status, 42);
    assert.deepEqual(commands(result), [
      ['systemctl', '--user', 'unset-environment', 'HYPRLAND_INSTANCE_SIGNATURE', 'WAYLAND_DISPLAY'],
      ...(XAUTHORITY ? [] : [['systemctl', '--user', 'unset-environment', 'XAUTHORITY']]),
      ['systemctl', '--user', 'import-environment', 'DISPLAY', 'I3SOCK', ...(XAUTHORITY ? ['XAUTHORITY'] : [])],
    ]);
  }
});

test('unit is not pulled in by default.target or ordered after graphical.target', () => {
  const unit = fs.readFileSync(path.join(__dirname, '../quickshell.service'), 'utf8');
  const directives = unit.replace(/\\\r?\n/g, ' ').split(/\r?\n/)
    .map(line => line.trim()).filter(line => line && !/^[#;]/.test(line));
  for (const line of directives) {
    const match = line.match(/^(WantedBy|After)\s*=\s*(.*)$/);
    if (!match) continue;
    const forbidden = match[1] === 'WantedBy' ? 'default.target' : 'graphical.target';
    assert.ok(!match[2].split(/\s+/).includes(forbidden), `Forbidden startup dependency: ${line}`);
  }
});

test('unit launches the shell without requiring a NordVPN group', () => {
  const unit = fs.readFileSync(path.join(__dirname, '../quickshell.service'), 'utf8');
  assert.match(unit, /^ExecStart=%h\/dotfiles\/linux\/config\/quickshell\/scripts\/quickshell$/m);
  assert.doesNotMatch(unit, /newgrp/);
});

test('Hyprland launches the default shell with its Wayland environment', async t => {
  const f = await fixture(t);
  const result = f.run([], {
    DISPLAY: undefined,
    I3SOCK: undefined,
    HYPRLAND_INSTANCE_SIGNATURE: f.hyprland.signature,
    WAYLAND_DISPLAY: 'wayland-test',
    XDG_RUNTIME_DIR: f.hyprland.runtime,
    LAUNCH_STATUS: '23',
  });
  assert.equal(result.status, 23);
  assert.deepEqual(commands(result), [
    ['quickshell', '--path', path.join(f.home, 'dotfiles/linux/config/quickshell/shell.qml')],
  ]);
  assert.equal(result.calls[0].env.HYPRLAND_INSTANCE_SIGNATURE, f.hyprland.signature);
  assert.equal(result.calls[0].env.WAYLAND_DISPLAY, 'wayland-test');
});

test('Hyprland startup clears i3 variables before importing Wayland plumbing', async t => {
  const f = await fixture(t);
  const result = f.run(['--session-start'], {
    HYPRLAND_INSTANCE_SIGNATURE: f.hyprland.signature,
    WAYLAND_DISPLAY: 'wayland-test',
    XDG_RUNTIME_DIR: f.hyprland.runtime,
  });
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(commands(result), [
    ['systemctl', '--user', 'unset-environment', 'DISPLAY', 'I3SOCK', 'XAUTHORITY'],
    ['systemctl', '--user', 'import-environment', 'HYPRLAND_INSTANCE_SIGNATURE', 'WAYLAND_DISPLAY', 'XDG_RUNTIME_DIR'],
    ['systemctl', '--user', 'start', 'quickshell.service'],
  ]);
});

test('incomplete Hyprland environment fails without falling back to i3', async t => {
  const f = await fixture(t);
  const result = f.run([], {
    HYPRLAND_INSTANCE_SIGNATURE: f.hyprland.signature,
    WAYLAND_DISPLAY: undefined,
    XDG_RUNTIME_DIR: f.hyprland.runtime,
  });
  assert.equal(result.status, 1);
  assert.match(result.stderr, /incomplete Hyprland Wayland environment/);
  assert.deepEqual(result.calls, []);
});

test('bar selects the native workspace model for the active session', () => {
  const bar = fs.readFileSync(path.resolve(__dirname, '../Bar.qml'), 'utf8');
  assert.match(bar, /^import Quickshell\.Hyprland$/m);
  assert.match(bar, /^import Quickshell\.I3$/m);
  assert.match(bar, /model: root\.hyprlandSession \? Hyprland\.workspaces : I3\.workspaces/);
  assert.match(bar, /workspace\.name\.startsWith\("special:"\)/);
  assert.match(bar, /source: root\.icon\("boxes"\)/);
  assert.match(bar, /specialWorkspaceState\.id === workspace\.id/);
  assert.match(bar, /event\.name === "activespecial" \|\| event\.name === "activespecialv2"/);
  assert.match(bar, /readonly property bool occupied: root\.hyprlandSession/);
  assert.match(bar, /workspace\.lastIpcObject\.windows > 0/);
  assert.match(bar, /readonly property real mouthAngle: 0\.42/);
});

test('i3 explicitly runs the existing session startup helper', () => {
  const config = fs.readFileSync(path.resolve(__dirname, '../../i3/main.conf'), 'utf8');
  assert.match(config, /^\s*exec(?:_always)?\s+--no-startup-id\s+"\$HOME\/dotfiles\/linux\/config\/quickshell\/scripts\/quickshell --session-start"\s*$/m);
  assert.ok(fs.statSync(launcher).isFile());
  fs.accessSync(launcher, fs.constants.X_OK);
});
