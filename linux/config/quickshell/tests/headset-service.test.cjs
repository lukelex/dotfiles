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
