const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { test } = require('node:test');
const vm = require('node:vm');

const source = fs.readFileSync(path.join(__dirname, '../Bar.qml'), 'utf8');
const serviceSource = fs.readFileSync(path.join(__dirname, '../ConnectivityService.qml'), 'utf8');

test('wired connectivity is exposed and replaces a disconnected Wi-Fi icon', () => {
  assert.match(serviceSource, /readonly property bool ethernetConnected: service\._wiredDevices\.some\(device => device\.connected\)/);
  assert.match(serviceSource, /readonly property var _wiredDevices: Networking\.devices\.values\.filter\(device => device\.type === DeviceType\.Wired\)/);
  assert.match(source, /!connectivity\.wifiConnected && connectivity\.ethernetConnected \? "ethernet-port"/);
  assert.match(source, /connectivity\.wifiConnected \|\| connectivity\.ethernetConnected \? root\.foreground : root\.muted/);
});

test('battery status is hidden when no battery is available', () => {
  assert.match(source, /visible: root\.batteryAvailable\n          color: root\.batteryAvailable && root\.batteryPercentage < 15/);
});

test('power-source changes notify once per transition after the battery is ready', () => {
  const match = source.match(/  function updatePowerSource\(\) \{[^]*?\n  \}/);
  assert.ok(match);
  assert.match(source, /function onOnBatteryChanged\(\) \{ root\.updatePowerSource\(\) \}/);
  assert.match(source, /function onReadyChanged\(\) \{ root\.updatePowerSource\(\) \}/);

  const root = { previousOnBattery: null, quickshellScripts: '/scripts' };
  const UPower = { onBattery: false, displayDevice: { ready: false, isPresent: true, percentage: 0.724 } };
  const powerNotification = { command: null, running: false };
  const batteryStatus = { running: false };
  const updatePowerSource = vm.runInNewContext(`(${match[0]})`, { root, UPower, powerNotification, batteryStatus });

  updatePowerSource();
  assert.equal(root.previousOnBattery, null);
  UPower.displayDevice.ready = true;
  updatePowerSource();
  assert.equal(powerNotification.command, null);
  UPower.onBattery = true;
  updatePowerSource();
  assert.deepEqual(Array.from(powerNotification.command), ['/scripts/battery', 'power', 'unplugged', '72']);
  assert.equal(batteryStatus.running, true);
  powerNotification.running = false;
  updatePowerSource();
  assert.equal(powerNotification.running, false);
  UPower.onBattery = false;
  updatePowerSource();
  assert.deepEqual(Array.from(powerNotification.command), ['/scripts/battery', 'power', 'plugged', '72']);
});

test('battery icon reserves critical for 0–14% and full for 90–100%', () => {
  const match = source.match(/  function batteryIcon\(\) \{[^]*?\n  \}/);
  assert.ok(match);
  const root = { batteryState: 'discharging', batteryPercentage: 0 };
  const batteryIcon = vm.runInNewContext(`(${match[0]})`, { root });

  for (const [percentage, expected] of [
    [0, 'battery-warning'], [14, 'battery-warning'], [15, 'battery-low'],
    [39, 'battery-low'], [40, 'battery-medium'], [64, 'battery-medium'], [65, 'battery-high'],
    [89, 'battery-high'], [90, 'battery-full'], [100, 'battery-full'],
  ]) {
    root.batteryPercentage = percentage;
    assert.equal(batteryIcon(), expected, `${percentage}%`);
    assert.ok(fs.existsSync(path.join(__dirname, '../../lucide/svg', `${expected}.svg`)));
  }

  root.batteryState = 'charging';
  root.batteryPercentage = 50;
  assert.equal(batteryIcon(), 'battery-charging');
  assert.match(fs.readFileSync(path.join(__dirname, '../ControlCenter.qml'), 'utf8'),
    /color: popup\.controller\.batteryAvailable && popup\.controller\.batteryPercentage < 15/);
});

test('NordVPN status exposes its active location', () => {
  assert.match(source, /property string vpnLocation: ""/);
  assert.match(source, /root\.vpnLocation = output\[6\] \|\| ""/);
});
