const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');
const source = fs.readFileSync(path.join(__dirname, '../ConnectivityService.qml'), 'utf8');

function createService() {
  const service = { trafficMonitoringEnabled: true,
    _wiredDevices: [{ name: 'eth0', connected: true }], _wifiDevices: [{ name: 'wlan0', connected: true }] };
  Object.defineProperties(service, {
    _trafficDevices: { get: () => [...service._wiredDevices, ...service._wifiDevices].filter(device => device.connected) },
    _trafficInterfaces: { get: () => service._trafficDevices.map(device => device.name).join(',') },
  });
  const context = vm.createContext({ service });
  for (const name of ['resetTraffic', 'pruneTraffic', 'sampleTraffic', 'formatSpeed', 'connectionSpeed']) {
    const match = source.match(new RegExp(`^  function ${name}\\([^]*?\\n  \\}`, 'm'));
    const javascript = match[0].replace(/^[^{]+/, signature => signature.replace(/:\s*\w+/g, ''));
    service[name] = vm.runInContext(`(${javascript})`, context);
  }
  service.resetTraffic();
  return service;
}

const row = (name, rx, tx) => `${name}: ${rx} 0 0 0 0 0 0 0 ${tx} 0 0 0 0 0 0 0`;
const snapshot = (rx, tx) => [row('eth0', rx, tx), row('wlan0', rx * 2, tx * 2), row('tun0', rx * 10, tx * 10), row('lo', rx * 20, tx * 20)].join('\n');

test('traffic uses elapsed time and physical interfaces without VPN/loopback duplication', () => {
  const service = createService();
  service.sampleTraffic(snapshot(1000, 500), 1000);
  assert.equal(service.connectionSpeed(true, 'download'), -1);
  service.sampleTraffic(snapshot(3000, 1500), 3000);
  assert.equal(service.connectionSpeed(true, 'download'), 1000);
  assert.equal(service.connectionSpeed(false, 'upload'), 1000);
  assert.deepEqual(Object.keys(service._deviceSpeeds).sort(), ['eth0', 'wlan0']);
  service.sampleTraffic(snapshot(3000, 1500), 4000);
  assert.equal(service.connectionSpeed(true, 'download'), 0);
});

test('counter resets and missing samples affect only that device', () => {
  const service = createService();
  service.sampleTraffic(snapshot(1000, 500), 1000);
  service.sampleTraffic([row('eth0', 2000, 1000), row('wlan0', 10, 5)].join('\n'), 2000);
  assert.equal(service.connectionSpeed(true, 'download'), 1000);
  assert.equal(service.connectionSpeed(false, 'download'), -1);
  service.sampleTraffic(row('eth0', 3000, 1500), 3000);
  assert.equal(service.connectionSpeed(true, 'download'), 1000);
  assert.equal(service.connectionSpeed(false, 'download'), -1);
});

test('disconnects and same-name replacement devices retain other baselines', () => {
  const service = createService();
  service.sampleTraffic(snapshot(1000, 500), 1000);
  service._wifiDevices[0].connected = false;
  service.pruneTraffic();
  service.sampleTraffic(snapshot(2000, 1000), 2000);
  assert.equal(service.connectionSpeed(true, 'download'), 1000);
  assert.equal(service._trafficSamples.wlan0, undefined);
  service._wiredDevices = [{ name: 'eth0', connected: true }];
  service.pruneTraffic();
  service.sampleTraffic(snapshot(3000, 1500), 3000);
  assert.equal(service.connectionSpeed(true, 'download'), -1);
});

test('suspend gaps, backwards clocks and reopening establish new baselines', () => {
  const service = createService();
  service.sampleTraffic(snapshot(1000, 500), 1000);
  service.sampleTraffic(snapshot(1000000, 500000), 10000);
  assert.equal(service.connectionSpeed(true, 'download'), -1);
  service.sampleTraffic(snapshot(1001000, 501000), 9000);
  assert.equal(service.connectionSpeed(true, 'download'), -1);
  service.trafficMonitoringEnabled = false;
  service.resetTraffic();
  service.sampleTraffic(snapshot(2000000, 1000000), 11000);
  assert.equal(Object.keys(service._trafficSamples).length, 0);
  service.trafficMonitoringEnabled = true;
  service.sampleTraffic(snapshot(2001000, 1001000), 12000);
  assert.equal(service.connectionSpeed(true, 'download'), -1);
});

test('each wired row selects its own device rather than the aggregate', () => {
  const service = createService();
  service._wiredDevices.push({ name: 'eth1', connected: true });
  service.sampleTraffic(snapshot(1000, 500) + '\n' + row('eth1', 1000, 500), 1000);
  service.sampleTraffic(snapshot(2000, 1000) + '\n' + row('eth1', 5000, 2500), 2000);
  assert.equal(service.connectionSpeed(true, 'download', 'eth0'), 1000);
  assert.equal(service.connectionSpeed(true, 'download', 'eth1'), 4000);
});

test('rates distinguish unavailable from idle and scale byte units', () => {
  const service = createService();
  assert.equal(service.formatSpeed(-1), '—');
  assert.equal(service.formatSpeed(NaN), '—');
  assert.equal(service.formatSpeed(0), '0 B/s');
  assert.equal(service.formatSpeed(1536), '1.5 KiB/s');
  assert.equal(service.formatSpeed(2 * 1024 ** 2), '2.0 MiB/s');
});
