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
  assert.match(source, /visible: root\.batteryAvailable && panel\.width >= 840\n          color: root\.batteryAvailable && root\.batteryPercentage < 15/);
});

test('notification indicator reflects active notifications, not retained history', () => {
  assert.match(source, /visible: root\.notificationService\.popup\.length > 0/);
  assert.match(source, /active notifications/);
  assert.doesNotMatch(source, /visible: root\.notificationService\.history\.length > 0/);
});

test('resize mode follows i3 mode and Hyprland submap events with a themed bar indicator', () => {
  assert.match(source, /I3IpcListener \{\s+subscriptions: root\.hyprlandSession \? \[\] : \["mode", "binding"\]\s+onIpcEvent: event => \{\s+root\.handleI3ModeEvent\(event\)\s+root\.handleI3BindingEvent\(event\)\s+\}/);
  assert.match(source, /event\.name === "submap"[\s\S]*?String\(event\.data \|\| ""\) === "resize"/);
  assert.match(source, /color: root\.controlActive[\s\S]*?visible: root\.resizeMode/);
  assert.match(source, /text: "Resize"/);
  assert.ok(fs.existsSync(path.join(__dirname, '../../lucide/svg/scan-line.svg')));
});

test('power-source changes notify once per transition after the battery is ready', () => {
  const match = source.match(/  function updatePowerSource\(\) \{[^]*?\n  \}/);
  assert.ok(match);
  assert.match(source, /function onOnBatteryChanged\(\) \{ root\.updatePowerSource\(\) \}/);
  assert.match(source, /function onReadyChanged\(\) \{ root\.updatePowerSource\(\); root\.checkBatteryWarnings\(\) \}/);

  const root = {
    previousOnBattery: null, quickshellScripts: '/scripts', batteryState: 'discharging',
    batteryPercentage: 72,
    updateBatteryStatus() { this.batteryAvailable = UPower.displayDevice.ready; },
  };
  const UPower = { onBattery: false, displayDevice: { ready: false, isPresent: true, percentage: 0.724 } };
  const powerNotification = { command: null, running: false };
  const batteryWarnings = { running: false };
  const updatePowerSource = vm.runInNewContext(`(${match[0]})`, { root, UPower, powerNotification, batteryWarnings });

  updatePowerSource();
  assert.equal(root.previousOnBattery, null);
  UPower.displayDevice.ready = true;
  updatePowerSource();
  assert.equal(powerNotification.command, null);
  UPower.onBattery = true;
  updatePowerSource();
  assert.deepEqual(Array.from(powerNotification.command), ['/scripts/battery', 'power', 'unplugged', '72', 'discharging']);
  assert.equal(batteryWarnings.running, true);
  powerNotification.running = false;
  updatePowerSource();
  assert.equal(powerNotification.running, false);
  UPower.onBattery = false;
  updatePowerSource();
  assert.deepEqual(Array.from(powerNotification.command), ['/scripts/battery', 'power', 'plugged', '72', 'discharging']);
});

test('UPower battery changes update charge, state, health, and time without polling', () => {
  const stateNames = {
    Unknown: 0, Charging: 1, Discharging: 2, Empty: 3, FullyCharged: 4,
    PendingCharge: 5, PendingDischarge: 6,
  };
  const context = vm.createContext({
    UPowerDeviceState: stateNames,
    UPower: { displayDevice: {
      ready: true, isPresent: true, percentage: 0.934, state: 2,
      healthSupported: true, healthPercentage: 87.6,
      timeToEmpty: 3660, timeToFull: 0,
    } },
  });
  const root = { batteryAvailable: false, batteryHealthAvailable: false };
  for (const name of ['batteryStateName', 'formatBatteryTime']) {
    const match = source.match(new RegExp(`  function ${name}\\([^]*?\\n  \\}`));
    assert.ok(match, `Missing ${name}`);
    root[name] = vm.runInContext(`(${match[0]})`, context);
  }
  context.root = root;
  const updateMatch = source.match(/  function updateBatteryStatus\([^]*?\n  \}/);
  assert.ok(updateMatch);
  root.updateBatteryStatus = vm.runInContext(`(${updateMatch[0]})`, context);
  root.updateBatteryStatus();

  assert.equal(root.batteryPercentage, 93);
  assert.equal(root.batteryState, 'discharging');
  assert.equal(root.batteryTime, '1 hr 1 min');
  assert.equal(root.batteryHealthAvailable, true);
  assert.equal(root.batteryHealth, 87.6);
  assert.match(source, /function onPercentageChanged\(\) \{ root\.updateBatteryStatus\(\); root\.checkBatteryWarnings\(\) \}/);
  assert.doesNotMatch(source, /interval: 30000\n\s+running: true\n\s+repeat: true\n\s+onTriggered: batteryStatus/);
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

test('VPN lifecycle is independent of local control status polling', () => {
  assert.match(source, /readonly property VpnService vpnService: VpnService/);
  assert.doesNotMatch(source, /nordvpn status|vpn_status/);
});
