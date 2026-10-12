const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');
const bar = fs.readFileSync(path.resolve(__dirname, '../Bar.qml'), 'utf8');
const center = fs.readFileSync(path.resolve(__dirname, '../ConnectivityCenter.qml'), 'utf8');

test('Bluetooth has its own bar target and independent hover/click/close lifecycle', () => {
  assert.match(bar, /property var bluetoothTarget: null/);
  assert.match(bar, /id: bluetoothCenter\s+bluetoothOnly: true/);
  assert.match(bar, /Accessible.name: "Network connections"/);
  assert.doesNotMatch(bar, /Wi-Fi and Bluetooth/);
  assert.match(bar, /Accessible.name: "Bluetooth"[^]*?onEntered:[^\n]*panel.openBluetooth\(\)[^]*?onExited: bluetoothCenter.scheduleClose\(\)[^]*?onClicked: panel.openBluetooth\(true\)/);
  assert.equal((bar.match(/ConnectivityService \{/g) || []).length, 1);
  assert.match(bar, /wifiScanningEnabled: root.connectivityTarget !== null && root.connectivityTarget.visible/);
  assert.match(bar, /trafficMonitoringEnabled: root.connectivityTarget !== null && root.connectivityTarget.visible/);
});

test('opening Bluetooth closes other panels and routes to the current screen instance', () => {
  const calls = [];
  const bluetoothCenter = { requestOpen: pin => calls.push(['bluetooth', pin]) };
  const root = { bluetoothTarget: null };
  for (const method of ['cancelHoverClose', 'closeConnectivity', 'closeAudioOutput', 'closeDateTime', 'closeNotifications', 'closeGitHubReviewCenter', 'closeBluetooth'])
    root[method] = (...args) => calls.push([method, ...args]);
  const match = bar.match(/      function openBluetooth\(pin = false\) \{([^]*?)\n      \}/);
  assert.ok(match);
  vm.runInNewContext(`(function(pin) { ${match[1]} })(true)`, {
    root, bluetoothCenter, controlCenter: { requestClose: () => calls.push(['control']) },
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

test('Bluetooth-only presentation excludes network controls and network side effects', () => {
  assert.match(center, /if \(!popup.bluetoothOnly\) \{\s+popup.controller.refreshControlStatus\(\)/);
  assert.match(center, /text: popup.bluetoothOnly \? "Bluetooth" : "Network"/);
  assert.match(center, /title: "Wi-Fi"\s+visible: !popup.bluetoothOnly/);
  assert.match(center, /title: "NordVPN"\s+visible: !popup.bluetoothOnly/);
  assert.match(center, /title: "Bluetooth"\s+visible: popup.bluetoothOnly/);
  assert.match(center, /entries: popup.bluetoothOnly \? popup.service.connectedBluetoothDevices : \[\]/);
  assert.match(center, /entries: popup.bluetoothOnly \? \[\] : popup.service.savedNetworks/);
  assert.match(center, /options: popup.bluetoothOnly \? \[[^]*?"Bluetooth settings"[^]*?\] : \[[^]*?"Network settings"/);
});
