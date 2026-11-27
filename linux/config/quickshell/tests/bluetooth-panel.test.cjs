const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');
const bar = fs.readFileSync(path.resolve(__dirname, '../Bar.qml'), 'utf8');
const center = fs.readFileSync(path.resolve(__dirname, '../ConnectivityCenter.qml'), 'utf8');
const bluetoothSettings = fs.readFileSync(path.resolve(__dirname, '../BluetoothSettings.qml'), 'utf8');
const wifiSettings = fs.readFileSync(path.resolve(__dirname, '../WifiSettings.qml'), 'utf8');

test('Bluetooth has its own bar target and independent hover/click/close lifecycle', () => {
  assert.match(bar, /property var bluetoothTarget: null/);
  assert.match(bar, /id: bluetoothCenter\s+bluetoothOnly: true/);
  assert.match(bar, /Accessible.name: "Network connections"/);
  assert.doesNotMatch(bar, /Wi-Fi and Bluetooth/);
  assert.match(bar, /Accessible.name: "Bluetooth"[^]*?onEntered:[^\n]*panel.openBluetooth\(\)[^]*?onExited: bluetoothCenter.scheduleClose\(\)[^]*?onClicked: panel.openBluetooth\(true\)/);
  assert.equal((bar.match(/module: "ConnectivityService.qml"/g) || []).length, 1);
  assert.match(bar, /wifiScanningEnabled: Qt\.binding\(\(\) => root.connectivityTarget !== null && root.connectivityTarget.visible/);
  assert.match(bar, /trafficMonitoringEnabled: Qt\.binding\(\(\) => root.connectivityTarget !== null && root.connectivityTarget.visible/);
});

test('opening Bluetooth closes other panels and routes to the current screen instance', () => {
  const calls = [];
  const bluetoothCenter = { requestOpen: pin => calls.push(['bluetooth', pin]) };
  const root = { bluetoothTarget: null };
  for (const method of ['cancelHoverClose', 'closeConnectivity', 'closeAudioOutput', 'closeDateTime', 'closeNotifications', 'closeBluetooth'])
    root[method] = (...args) => calls.push([method, ...args]);
  const match = bar.match(/      function openBluetooth\(pin = false\) \{([^]*?)\n      \}/);
  assert.ok(match);
  vm.runInNewContext(`(function(pin) { ${match[1]} })(true)`, {
    root, panel: { cancelHoverClose() {} }, bluetoothCenter, controlCenter: { requestClose: () => calls.push(['control']) },
  });
  assert.equal(root.bluetoothTarget, bluetoothCenter);
  assert.ok(calls.some(c => c[0] === 'closeConnectivity' && c[1] === false));
  assert.deepEqual(calls.at(-1), ['bluetooth', true]);
});

test('closing network siblings also closes Bluetooth unless explicitly excluded', () => {
  const calls = [];
  const root = { connectivityTarget: { requestClose: () => calls.push('network') }, closeBluetooth: () => calls.push('bluetooth') };
  const match = bar.match(/  function closeConnectivity\(includeBluetooth = true\) \{([^]*?)\n  \}/);
  assert.ok(match);
  const close = vm.runInNewContext(`(function(includeBluetooth = true) { ${match[1]} })`, { root });
  close();
  assert.deepEqual(calls, ['network', 'bluetooth']);
  calls.length = 0;
  close(false);
  assert.deepEqual(calls, ['network']);
});

test('network and Bluetooth can still open when Control Center failed to load', () => {
  for (const [method, target] of [['openConnectivity', 'connectivity'], ['openBluetooth', 'bluetooth']]) {
    const root = {};
    for (const name of ['cancelHoverClose', 'closeBluetooth', 'closeConnectivity', 'closeAudioOutput', 'closeDateTime', 'closeNotifications'])
      root[name] = () => {};
    const opened = [];
    const center = { requestOpen: pin => opened.push(pin) };
    const body = bar.match(new RegExp(`      function ${method}\\(pin = false\\) \\{([^]*?)\\n      \\}`))[1];
    const open = vm.runInNewContext(`(function(pin = false) { ${body} })`, {
      root, panel: { cancelHoverClose() {} }, controlCenter: null, [`${target}Center`]: center,
    });
    open();
    open(true);
    assert.deepEqual(opened, [false, true]);
    assert.equal(root[`${target}Target`], center);
  }
});

test('Bluetooth-only presentation excludes network controls and network side effects', () => {
  assert.match(center, /if \(!popup.bluetoothOnly\) \{\s+popup.controller.refreshControlStatus\(\)/);
  assert.match(center, /text: popup.bluetoothOnly \? "Bluetooth" : "Network"/);
  const network = fs.readFileSync(path.resolve(__dirname, '../NetworkControls.qml'), 'utf8');
  const bluetooth = fs.readFileSync(path.resolve(__dirname, '../BluetoothControls.qml'), 'utf8');
  assert.match(center, /module: popup.bluetoothOnly \? "BluetoothControls.qml" : "NetworkControls.qml"/);
  assert.doesNotMatch(bluetooth, /vpnService|wifiEnabled|Quickshell.Networking/);
  assert.doesNotMatch(network, /bluetoothEnabled|Quickshell.Bluetooth/);
  assert.match(center, /onActivated: popup.controller.openSystemSettings\(popup.panel.screen, popup.bluetoothOnly \? "bluetooth" : "wifi"\)/);
});

test('Bluetooth and Wi-Fi devices share the same right-action entry layout', () => {
  assert.match(wifiSettings, /ConnectivityEntry \{[^]*?actionDelegate: Component/);
  assert.match(bluetoothSettings, /ConnectivityEntry \{[^]*?title: row\.deviceName[^]*?actionDelegate: Component/);
  assert.match(bluetoothSettings, /row\.connected \? "Disconnect" : row\.paired \? "Connect" : "Pair"/);
});
