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
  popup.audioService = { refresh() {} };
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
    popup, content, closeAnim,
    openAnim: { start() { opened = true; } },
  })();
  assert.equal(opened, true);
  assert.deepEqual(content, { opacity: 0.6, y: 3 });
});

test('opening a hidden Control Center initializes the entry animation', () => {
  const popup = { visible: false, closePending: false };
  popup.audioService = { refresh() {} };
  const content = { opacity: 1, y: 0 };
  loadFunction('ControlCenter.qml', 'requestOpen', {
    popup, content,
    closeAnim: { running: false, stop() {} }, openAnim: { start() {} },
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

test('sensor temperature selection only accepts matching chips with usable readings', () => {
  const sensorTemperature = loadFunction('Bar.qml', 'sensorTemperature', {});
  const sensors = {
    'amdgpu-pci-c600': { edge: { temp1_input: 49 } },
    'k10temp-pci-00c3': { Tctl: { temp1_input: 67.375 } },
    'spd5118-i2c-16-50': { temp1: { temp1_input: 49.5 } },
  };

  assert.equal(sensorTemperature(sensors, /^(k10temp|coretemp|zenpower|cpu_thermal)/i), 67.375);
  assert.equal(sensorTemperature(sensors, /^(amdgpu|nouveau|nvidia)/i), 49);
  assert.equal(sensorTemperature(sensors, /^nvidia/i), null);
});

test('Control Center attaches temperature to each available processor label', () => {
  const source = fs.readFileSync(path.join(__dirname, '..', 'ControlCenter.qml'), 'utf8');
  assert.match(source, /title: "CPU" \+ \(popup\.controller\.cpuTemperatureAvailable/);
  assert.match(source, /title: "GPU - " \+ Math\.round\(popup\.controller\.gpuTemperature\)/);
  assert.match(source, /percentage: popup\.controller\.gpuUsage/);
  assert.match(source, /visible: popup\.controller\.gpuTemperatureAvailable && popup\.controller\.gpuUsageAvailable/);
});

test('hover centers do not grab focus from their bar triggers', () => {
  for (const file of ['ControlCenter.qml', 'NotificationCenter.qml']) {
    const source = fs.readFileSync(path.join(__dirname, '..', file), 'utf8');
    assert.match(source, /grabFocus: false/);
  }
});

test('Control Center keeps tray content bounded and preserves hover menus', () => {
  const source = fs.readFileSync(path.join(__dirname, '..', 'ControlCenter.qml'), 'utf8');
  assert.match(source, /implicitHeight: Math\.min\(sections\.implicitHeight \+ 32, maxHeight\)/);
  assert.match(source, /contentHeight: sections\.implicitHeight/);
  assert.match(source, /TrayModule/);
  assert.match(source, /else if \(!trayModule\.menuOpen\)/);
  assert.match(source, /trayModule\.closeMenu\(\)/);
});

test('tray module uses native icons and routes StatusNotifier actions', () => {
  const source = fs.readFileSync(path.join(__dirname, '..', 'TrayModule.qml'), 'utf8');
  assert.match(source, /import Quickshell\.Services\.SystemTray/);
  assert.match(source, /readonly property var items: SystemTray\.items/);
  assert.match(source, /readonly property bool available: items\.values\.length > 0/);
  assert.match(source, /source: cell\.modelData\.icon/);
  assert.match(source, /sourceSize: Qt\.size\(24, 24\)/);
  assert.match(source, /cell\.modelData\.activate\(\)/);
  assert.match(source, /cell\.modelData\.secondaryActivate\(\)/);
  assert.match(source, /QsMenuAnchor/);
  assert.match(source, /menu: tray\.activeMenuItem \? tray\.activeMenuItem\.menu : null/);
});

test('platform tray menus run with QApplication support', () => {
  const source = fs.readFileSync(path.join(__dirname, '..', 'shell.qml'), 'utf8');
  assert.match(source, /^\/\/\@ pragma UseQApplication/m);
});
