const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');

const source = fs.readFileSync(path.join(__dirname, '../ConnectivityService.qml'), 'utf8');

function createService() {
  const service = { trafficMonitoringEnabled: true, _trafficInterfaces: 'eth0,wlan0', _trafficSample: null };
  const context = vm.createContext({ service });
  for (const name of ['resetTraffic', 'sampleTraffic', 'formatSpeed', 'connectionSpeed']) {
    const match = source.match(new RegExp(`^  function ${name}\\([^]*?\\n  \\}`, 'm'));
    const javascript = match[0].replace(/^[^{]+/, signature => signature.replace(/:\s*\w+/g, ''));
    service[name] = vm.runInContext(`(${javascript})`, context);
  }
  service.resetTraffic();
  return service;
}

function snapshot(rx, tx) {
  const row = (name, received, sent) => `${name}: ${received} 0 0 0 0 0 0 0 ${sent} 0 0 0 0 0 0 0`;
  return [row('eth0', rx, tx), row('wlan0', rx * 2, tx * 2), row('tun0', rx * 10, tx * 10), row('lo', rx * 20, tx * 20)].join('\n');
}

test('traffic uses elapsed time and physical interfaces without VPN/loopback duplication', () => {
  const service = createService();
  service.sampleTraffic(snapshot(1000, 500), 1000);
  assert.equal(service.downloadSpeed, -1);
  service.sampleTraffic(snapshot(3000, 1500), 3000);
  assert.equal(service.downloadSpeed, 3000);
  assert.equal(service.uploadSpeed, 1500);
  service.sampleTraffic(snapshot(3000, 1500), 4000);
  assert.equal(service.downloadSpeed, 0);
  assert.equal(service.uploadSpeed, 0);
});

test('counter resets and missing samples never produce spikes or negative speeds', () => {
  const service = createService();
  service.sampleTraffic(snapshot(1000, 500), 1000);
  service.sampleTraffic(snapshot(100, 50), 2000);
  assert.equal(service.downloadSpeed, -1);
  service.sampleTraffic(snapshot(200, 100), 3000);
  assert.equal(service.downloadSpeed, 300);
  service.sampleTraffic('eth0: invalid', 4000);
  assert.equal(service.downloadSpeed, -1);
  service.sampleTraffic(snapshot(5000, 1000), 5000);
  assert.equal(service.downloadSpeed, -1);
});

test('reopening establishes a new baseline and hidden panels ignore samples', () => {
  const service = createService();
  service.sampleTraffic(snapshot(1000, 500), 1000);
  service.trafficMonitoringEnabled = false;
  service.resetTraffic();
  service.sampleTraffic(snapshot(3000, 1500), 2000);
  assert.equal(service._trafficSample, null);
  service.trafficMonitoringEnabled = true;
  service.sampleTraffic(snapshot(9000, 4500), 9000);
  assert.equal(service.downloadSpeed, -1);
});

test('rates distinguish unavailable from idle and scale byte units', () => {
  const service = createService();
  assert.equal(service.formatSpeed(-1), '—');
  assert.equal(service.formatSpeed(NaN), '—');
  assert.equal(service.formatSpeed(0), '0 B/s');
  assert.equal(service.formatSpeed(1536), '1.5 KiB/s');
  assert.equal(service.formatSpeed(2 * 1024 ** 2), '2.0 MiB/s');
});

test('device rows show only their own connection traffic', () => {
  const service = createService();
  service._wiredDevices = [{ name: 'eth0', connected: true }, { name: 'eth1', connected: false }];
  service._wifiDevices = [{ name: 'wlan0', connected: true }];
  assert.equal(service.connectionSpeed(true, 'download'), -1);
  service.sampleTraffic(snapshot(1000, 500), 1000);
  service.sampleTraffic(snapshot(3000, 1500), 3000);
  assert.equal(service.connectionSpeed(true, 'download'), 1000);
  assert.equal(service.connectionSpeed(true, 'upload'), 500);
  assert.equal(service.connectionSpeed(false, 'download'), 2000);
  assert.equal(service.connectionSpeed(false, 'upload'), 1000);
  service.resetTraffic();
  assert.equal(service.connectionSpeed(false, 'upload'), -1);
});
