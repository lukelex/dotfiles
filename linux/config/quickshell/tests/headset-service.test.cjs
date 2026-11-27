const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');

const source = fs.readFileSync(path.join(__dirname, '..', 'HeadsetService.qml'), 'utf8');
const match = source.match(/  function parseDevices\([^]*?\n  \}/);
const parse = vm.runInNewContext(`(${match[0]})`);
const device = (level, status = 'BATTERY_AVAILABLE') => ({
  device: 'Audeze Maxwell', battery: { level, status },
});
const read = devices => JSON.parse(JSON.stringify(parse(JSON.stringify({ devices }))));

test('reads native percentages including empty and full batteries', () => {
  assert.deepEqual(read([device(0), device(75), device(100)]), [
    { name: 'Audeze Maxwell', percentage: 0, charging: false },
    { name: 'Audeze Maxwell', percentage: 75, charging: false },
    { name: 'Audeze Maxwell', percentage: 100, charging: false },
  ]);
});

test('charging without a reported level remains visible without fabricating a percentage', () => {
  assert.deepEqual(read([device(42, 'BATTERY_CHARGING'), device(-1, 'BATTERY_CHARGING')]), [
    { name: 'Audeze Maxwell', percentage: 42, charging: true },
    { name: 'Audeze Maxwell', percentage: null, charging: true },
  ]);
});

test('mixed headset models are independent of brand, USB IDs and list order', () => {
  const devices = [
    { ...device(80), device: 'Logitech G533', id_vendor: '0x046d', id_product: '0x0a66' },
    { ...device(25), device: 'SteelSeries Arctis 7' },
    { ...device(-1, 'BATTERY_CHARGING'), device: 'Corsair Headset Device' },
    { ...device(65), device: 'HyperX Cloud II Wireless' },
    { ...device(90, 'BATTERY_UNAVAILABLE'), device: 'Disconnected headset' },
    { ...device(90, 'BATTERY_ERROR'), device: 'Failed headset' },
    { device: 'Wired headset without battery' },
  ];
  const expected = [
    { name: 'Logitech G533', percentage: 80, charging: false },
    { name: 'SteelSeries Arctis 7', percentage: 25, charging: false },
    { name: 'Corsair Headset Device', percentage: null, charging: true },
    { name: 'HyperX Cloud II Wireless', percentage: 65, charging: false },
  ];
  assert.deepEqual(read(devices), expected);
  assert.deepEqual(read(devices.reverse()), expected.reverse());
});

test('charging does not make malformed or out-of-range levels valid', () => {
  assert.deepEqual(read([-2, 101, 4.5, '75', null].map(level => device(level, 'BATTERY_CHARGING'))), []);
});

test('disconnected and failed devices cannot expose retained levels', () => {
  for (const status of ['BATTERY_UNAVAILABLE', 'BATTERY_ERROR', 'BATTERY_TIMEOUT', 'UNKNOWN'])
    assert.deepEqual(read([device(75, status)]), []);
  assert.deepEqual(read([]), []);
});

test('rejects malformed measurements without losing a valid device', () => {
  assert.deepEqual(read([
    null, {}, { device: 'No battery' }, { battery: { level: 50, status: 'BATTERY_AVAILABLE' } },
    device(-1), device(101), device(4.5), device('75'), device(null), device(60),
  ]), [{ name: 'Audeze Maxwell', percentage: 60, charging: false }]);
});

test('malformed or missing JSON payload clears the snapshot', () => {
  for (const text of ['', 'not json', 'null', '{}', '{"devices":{}}'])
    assert.equal(parse(text).length, 0);
});

const bluetooth = vm.runInNewContext(`(${source.match(/  function bluetoothHeadphones\([^]*?\n  \}/)[0]})`);
const power = vm.runInNewContext(`(${source.match(/  function powerHeadphones\([^]*?\n  \}/)[0]})`, {
  UPowerDeviceType: { Headset: 17, Headphones: 19 },
  UPowerDeviceState: { Charging: 1, PendingCharge: 5 },
});
const merge = vm.runInNewContext(`(${source.match(/  function mergeDevices\([^]*?\n  \}/)[0]})`);
const connected = (icon, battery, extra = {}) => ({
  name: 'Wireless headphones', icon, connected: true, batteryAvailable: true, battery, ...extra,
});

test('connected Bluetooth headphones and headsets use native battery fractions', () => {
  assert.deepEqual(JSON.parse(JSON.stringify(bluetooth([
    connected('audio-headphones', 0), connected('audio-headset', 0.755), connected('audio-headphones', 1),
  ]))), [
    { name: 'Wireless headphones', percentage: 0, charging: false },
    { name: 'Wireless headphones', percentage: 76, charging: false },
    { name: 'Wireless headphones', percentage: 100, charging: false },
  ]);
});

test('other Bluetooth devices, missing readings and disconnected headphones do not appear', () => {
  assert.deepEqual(bluetooth([
    connected('input-mouse', 0.4), connected('audio-speakers', 0.4),
    connected('audio-headset', 0.4, { connected: false }),
    connected('audio-headphones', 0.4, { batteryAvailable: false }),
    ...[NaN, Infinity, -0.1, 1.1].map(value => connected('audio-headphones', value)),
  ]), []);
});

test('UPower headphone and headset types report charging and filter absent devices', () => {
  const device = { model: 'Wireless headphones', ready: true, isPresent: true, type: 19, percentage: 0.65, state: 1 };
  assert.deepEqual(JSON.parse(JSON.stringify(power([
    device, { ...device, type: 17, percentage: 0, state: 5 },
    { ...device, type: 18 }, { ...device, ready: false }, { ...device, isPresent: false },
    { ...device, percentage: 1.2 }, { ...device, percentage: NaN },
  ]))), [
    { name: 'Wireless headphones', percentage: 65, charging: true },
    { name: 'Wireless headphones', percentage: 0, charging: true },
  ]);
});

test('dongle and UPower readings take precedence over the same Bluetooth headset', () => {
  const usb = [{ name: 'Wireless headphones', percentage: null, charging: true }];
  const powerDevices = [{ name: 'Another headset', percentage: 86, charging: true }];
  const others = [
    { name: 'Wireless headphones', percentage: 40, charging: false },
    { name: 'Another headset', percentage: 85, charging: false },
    { name: 'Third headset', percentage: 10, charging: false },
  ];
  assert.deepEqual(JSON.parse(JSON.stringify(merge(usb, powerDevices, others))), [usb[0], powerDevices[0], others[2]]);
  assert.deepEqual(JSON.parse(JSON.stringify(merge([], [], others))), others);
});

test('identically named physical headsets remain separate within and across sources', () => {
  const usb = [{ name: 'Same model', percentage: 30, charging: false }];
  const bluetoothDevices = [
    { name: 'Same model', percentage: 30, charging: false },
    { name: 'Same model', percentage: 80, charging: false },
  ];
  assert.deepEqual(JSON.parse(JSON.stringify(merge(usb, [], bluetoothDevices))), [usb[0], bluetoothDevices[1]]);
  assert.deepEqual(JSON.parse(JSON.stringify(merge([], [], bluetoothDevices))), bluetoothDevices);
});

test('native Bluetooth watchers update the shared snapshot as devices and readings change', () => {
  assert.match(source, /bluetoothWatchers: Instantiator \{\s+model: Bluetooth\.devices\s*\n/);
  assert.match(source, /onBluetoothDevicesChanged: updateDevices\(\)/);
  for (const event of ['Connected', 'Icon', 'Name', 'BatteryAvailable', 'Battery'])
    assert.match(source, new RegExp(`on${event}Changed\\(\\) \\{ service\\.updateDevices\\(\\) \\}`));
  assert.match(source, /onPowerDevicesChanged: updateDevices\(\)/);
  for (const event of ['Ready', 'IsPresent', 'Type', 'Model', 'Percentage', 'State'])
    assert.match(source, new RegExp(`on${event}Changed\\(\\) \\{ service\\.updateDevices\\(\\) \\}`));
  assert.match(source, /service\.usbDevices = exitCode === 0 \? service\.parseDevices\(output\.text\) : \[\]/);
  assert.match(source, /service\.updateDevices\(\)\n\s+\}\n\s+\}/);
});
