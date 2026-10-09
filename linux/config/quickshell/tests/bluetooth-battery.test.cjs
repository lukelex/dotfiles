const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');

const source = fs.readFileSync(path.join(__dirname, '../ConnectivityService.qml'), 'utf8');

function setup() {
  const commands = [];
  const match = source.match(/^( +)function checkBluetoothBattery\([^]*?\n\1\}/m);
  assert.ok(match);
  const check = vm.runInNewContext(`(${match[0].replace('): void', ')')})`, {
    service: { _bluetoothBatteryWarnings: {} },
    Quickshell: { env: () => '/home/test', execDetached: command => commands.push(Array.from(command)) },
  });
  const device = { dbusPath: '/headphones', connected: true, batteryAvailable: true, battery: 0.15, name: 'Headphones' };
  return { check, commands, device };
}

test('already connected and newly connected low batteries notify once per connection', () => {
  const { check, commands, device } = setup();
  check(device);
  assert.equal(commands.length, 1);
  assert.equal(commands[0].at(-1), 'Headphones has 15% battery remaining.');
  assert.ok(commands[0].includes('normal'));
  assert.ok(commands[0].some(arg => arg.endsWith('/battery-low.svg')));
  device.battery = 0.1;
  check(device);
  assert.equal(commands.length, 1);
  device.connected = false;
  check(device);
  device.connected = true;
  check(device);
  assert.equal(commands.length, 2);
});

test('crossing the threshold rearms after recovery and tracks each device independently', () => {
  const { check, commands, device } = setup();
  device.battery = 0.16;
  check(device);
  assert.equal(commands.length, 0);
  device.battery = 0.15;
  check(device);
  check({ ...device, dbusPath: '/mouse', name: 'Mouse', battery: 0 });
  assert.equal(commands.length, 2);
  device.battery = 0.5;
  check(device);
  device.battery = 0.05;
  check(device);
  assert.equal(commands.length, 3);
});

test('unavailable and invalid battery readings neither notify nor rearm', () => {
  const { check, commands, device } = setup();
  device.batteryAvailable = false;
  check(device);
  assert.equal(commands.length, 0);
  device.batteryAvailable = true;
  for (const battery of [NaN, Infinity, -1, 2]) {
    device.battery = battery;
    check(device);
  }
  assert.equal(commands.length, 0);
  device.battery = 0.1;
  check(device);
  device.batteryAvailable = false;
  check(device);
  device.batteryAvailable = true;
  check(device);
  assert.equal(commands.length, 1);
});

test('device names are passed as arguments with notification markup escaped', () => {
  const { check, commands, device } = setup();
  device.name = '<Mouse & Keyboard>';
  check(device);
  assert.equal(commands[0].at(-1), '&lt;Mouse &amp; Keyboard&gt; has 15% battery remaining.');
});

test('native watchers cover startup, connections, battery availability and charge updates', () => {
  assert.match(source, /model: Bluetooth\.devices\.values/);
  for (const event of ['onConnectedChanged', 'onBatteryAvailableChanged', 'onBatteryChanged']) {
    assert.match(source, new RegExp(`${event}\\(\\) \\{ service\\.checkBluetoothBattery`));
  }
  assert.match(source, /Component\.onCompleted: service\.checkBluetoothBattery/);
});
