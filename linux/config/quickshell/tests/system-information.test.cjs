const assert = require('node:assert/strict');
const { test } = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const context = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(__dirname, '../SystemInformation.js'), 'utf8'), context);
const normalize = data => JSON.parse(JSON.stringify(context.normalize(data)));

test('generic opening resets the destination while contextual shortcuts retain their section and tab', () => {
  const source = fs.readFileSync(path.join(__dirname, '../Bar.qml'), 'utf8');
  const start = source.indexOf('  function openSystemSettings(');
  const end = source.indexOf('\n  SystemSettings {', start);
  const settings = { section: 'audio', open() {} };
  const root = {
    cancelHoverClose() {}, closeNotifications() {}, closeConnectivity() {},
    closeAudioOutput() {}, closeDateTime() {}, closeGitHubReviewCenter() {},
    panelsByScreen: {}, focusedPanel() { return null; }
  };
  const routing = vm.createContext({ root, systemSettings: settings });
  vm.runInContext(source.slice(start, end), routing);
  routing.openSystemSettings(null);
  assert.equal(settings.section, 'system');
  routing.openSystemSettings(null, 'notifications');
  assert.equal(settings.section, 'notifications');
  routing.openSystemSettings(null, 'audio');
  assert.equal(settings.section, 'audio');
  routing.openSystemSettings(null, 'connectivityPreferences');
  assert.equal(settings.section, 'connectivity');
  assert.equal(settings.connectivityTab, 'preferences');
  routing.openSystemSettings(null, 'wifi');
  assert.equal(settings.connectivityTab, 'networks');
  routing.openSystemSettings(null);
  assert.equal(settings.section, 'system');
});

test('uses login shell and separates hardware, session and multiple displays', () => {
  const info = normalize([
    { type: 'Title', result: { hostName: 'test-host', userShell: '/usr/bin/zsh' } },
    { type: 'Shell', result: { prettyName: 'quickshell' } },
    { type: 'DE', error: 'No DE found' },
    { type: 'WM', result: { prettyName: 'i3', protocolName: 'X11' } },
    { type: 'Uptime', result: { uptime: 90061000 } },
    { type: 'Display', result: [
      { name: 'Internal', output: { width: 1920, height: 1200, refreshRate: 60.002 } },
      { name: 'External', output: { width: 3840, height: 2160, refreshRate: 144 } }
    ] }
  ]);
  assert.equal(info.hostname, 'test-host');
  const session = info.groups.find(g => g.title === 'Desktop & session').rows;
  assert.equal(session.find(r => r.label === 'Login shell').value, '/usr/bin/zsh');
  assert.equal(session.find(r => r.label === 'Desktop / session').value, 'i3 · X11');
  assert.equal(session.find(r => r.label === 'Uptime').value, '1d 1h 1m');
  assert.equal(info.groups.find(g => g.title === 'Displays').rows.length, 2);
});

test('groups shared Btrfs capacity without merging independent filesystems', () => {
  const info = normalize([{ type: 'Disk', result: [
    { mountFrom: '/dev/a', mountpoint: '/', filesystem: 'btrfs', bytes: { used: 50, total: 100 } },
    { mountFrom: '/dev/a', mountpoint: '/home', filesystem: 'btrfs', bytes: { used: 50, total: 100 } },
    { mountFrom: '/dev/b', mountpoint: '/data', filesystem: 'ext4', bytes: { used: 25, total: 100 } }
  ] }]);
  const disks = info.groups.find(g => g.title === 'Storage').rows;
  assert.equal(disks.length, 2);
  assert.equal(disks[0].label, '/, /home');
  assert.equal(disks[0].usage, 0.5);
  assert.equal(disks[1].usage, 0.25);
});

test('handles missing modules, zero swap and legacy versus per-device swap', () => {
  assert.throws(() => normalize(null));
  assert.throws(() => normalize([{ type: 'OS', error: 'failed' }]));
  const swapRow = result => normalize([{ type: 'Swap', result }]).groups[0].rows.find(r => r.label === 'Swap');
  assert.equal(swapRow([]).value, 'None');
  assert.equal(swapRow({ used: 50, total: 100 }).usage, 0.5);
  assert.equal(swapRow([{ used: 25, total: 100 }, { used: 75, total: 100 }]).usage, 0.5);
  const hardware = normalize([{ type: 'Title', result: {} }]).groups[0].rows;
  assert.equal(hardware.find(r => r.label === 'Memory').value, 'Unavailable');
  assert.equal(hardware.find(r => r.label === 'Swap').value, 'Unavailable');
  assert.equal(context.bytes(NaN), 'Unavailable');
});
