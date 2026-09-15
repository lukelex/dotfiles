const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { test } = require('node:test');

const source = fs.readFileSync(path.join(__dirname, '../Bar.qml'), 'utf8');
const serviceSource = fs.readFileSync(path.join(__dirname, '../ConnectivityService.qml'), 'utf8');

test('wired connectivity is exposed and replaces a disconnected Wi-Fi icon', () => {
  assert.match(serviceSource, /readonly property bool ethernetConnected: service\._wiredDevices\.some\(device => device\.connected\)/);
  assert.match(serviceSource, /readonly property var _wiredDevices: Networking\.devices\.values\.filter\(device => device\.type === DeviceType\.Wired\)/);
  assert.match(source, /!connectivity\.wifiConnected && connectivity\.ethernetConnected \? "ethernet-port"/);
  assert.match(source, /connectivity\.wifiConnected \|\| connectivity\.ethernetConnected \? root\.foreground : root\.muted/);
});

test('battery status is hidden when no battery is available', () => {
  assert.match(source, /visible: root\.batteryAvailable\n          color: root\.batteryAvailable && root\.batteryPercentage <= 5/);
});

test('NordVPN status exposes its active location', () => {
  assert.match(source, /property string vpnLocation: ""/);
  assert.match(source, /root\.vpnLocation = output\[6\] \|\| ""/);
});
