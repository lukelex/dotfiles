const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');

function loadFunction(file, name, globals) {
  const source = fs.readFileSync(path.join(__dirname, '..', file), 'utf8');
  const match = source.match(new RegExp(`  function ${name}\\([^]*?\\n  \\}`));
  assert.ok(match, `Missing QML function ${name}`);
  return vm.runInNewContext(`(${match[0]})`, globals);
}

test('reopening Control Center cancels closing without resetting its position', () => {
  const popup = { visible: true, closePending: true };
  const content = { opacity: 0.6, y: 3 };
  let opened = false;
  const closeAnim = {
    running: true,
    stop() {
      assert.equal(popup.closePending, false);
      this.running = false;
    },
  };
  loadFunction('ControlCenter.qml', 'requestOpen', {
    popup, content, closeAnim, openAnim: { start() { opened = true; } },
  })();
  assert.equal(opened, true);
  assert.deepEqual(content, { opacity: 0.6, y: 3 });
});

test('opening a hidden Control Center initializes the entry animation', () => {
  const popup = { visible: false, closePending: false };
  const content = { opacity: 1, y: 0 };
  loadFunction('ControlCenter.qml', 'requestOpen', {
    popup, content, closeAnim: { running: false, stop() {} }, openAnim: { start() {} },
  })();
  assert.equal(popup.visible, true);
  assert.deepEqual(content, { opacity: 0, y: 10 });
});

test('VPN toggle ignores competing requests while the previous command runs', () => {
  const root = { nordVpnInstalled: true, vpnBusy: true, vpnConnected: false };
  const vpnToggle = { command: [], running: true };
  const controlRefreshTimer = { restart() { assert.fail('Busy toggle must be ignored'); } };
  loadFunction('Bar.qml', 'toggleVpn', { root, vpnToggle, controlRefreshTimer })();
  assert.deepEqual(vpnToggle.command, []);
});

test('VPN connects to the selected location', () => {
  const root = { nordVpnInstalled: true, vpnBusy: false };
  const vpnToggle = { command: [], running: false };
  const controlRefreshTimer = { restart() {} };
  loadFunction('Bar.qml', 'connectVpn', { root, vpnToggle, controlRefreshTimer })('Sweden');
  assert.deepEqual([...vpnToggle.command], ['nordvpn', 'connect', 'Sweden']);
  assert.equal(vpnToggle.running, true);
});

test('brightness ignores duplicate changes while the previous command is applying', () => {
  const root = {
    brightnessBusy: true,
    notificationService: { showOsd() { assert.fail('Busy brightness must not show an OSD'); } },
  };
  const brightnessSet = { value: 0, running: true };
  loadFunction('Bar.qml', 'setBrightness', { root, brightnessSet })(75);
  assert.deepEqual(brightnessSet, { value: 0, running: true });
});

test('brightness slider shows a spinner while the DDC command is running', () => {
  const source = fs.readFileSync(path.join(__dirname, '..', 'ControlCenter.qml'), 'utf8');
  assert.match(source, /busy: popup\.controller\.brightnessBusy/);
  assert.match(source, /running: spinner\.visible/);
});

test('hover centers do not grab focus from their bar triggers', () => {
  for (const file of ['ControlCenter.qml', 'NotificationCenter.qml']) {
    const source = fs.readFileSync(path.join(__dirname, '..', file), 'utf8');
    assert.match(source, /grabFocus: false/);
  }
});
