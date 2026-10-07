const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');
const source = fs.readFileSync(path.join(__dirname, '../VpnService.qml'), 'utf8');

function setup() {
  const service = { installed: true, state: 'disconnected', pending: false, generation: 0,
    error: '', statusError: '', location: '', country: '', locations: [] };
  const action = { running: false, command: [] };
  const status = { running: false };
  const confirmationTimeout = { running: false, restart() { this.running = true; }, stop() { this.running = false; } };
  Object.defineProperties(service, {
    connected: { get: () => service.state === 'connected' },
    statusKnown: { get: () => service.state !== 'unknown' },
    busy: { get: () => service.pending || action.running },
  });
  const context = vm.createContext({ service, action, status, confirmationTimeout, countries: { running: false } });
  for (const match of source.matchAll(/^  function \w+\([^]*?\n  \}/gm)) {
    const name = match[0].match(/function (\w+)/)[1];
    service[name] = vm.runInContext(`(${match[0]})`, context);
  }
  return { service, action, status, confirmationTimeout };
}

test('VPN retains busy state after command exit until fresh requested state is confirmed', () => {
  const { service, action, confirmationTimeout } = setup();
  service.connectLocation('Sweden');
  assert.deepEqual([...action.command], ['env', 'LC_ALL=C', 'timeout', '--kill-after=2s', '45s', 'nordvpn', 'connect', 'Sweden']);
  service.toggle();
  assert.equal(service.generation, 1);
  action.running = false;
  service.finishAction(0, 'Success');
  service.applyStatus('Status: Connected\nCountry: Sweden\nCity: Stockholm', 0, 1);
  assert.equal(service.pending, true, 'Old request must not confirm new action');
  service.applyStatus('Status: Connected\nCountry: Denmark', 0, 2);
  assert.equal(service.pending, true, 'Old destination is not confirmation');
  service.applyStatus('Status: Connected\nCountry: Sweden\nCity: Stockholm', 0, 2);
  assert.equal(service.pending, false);
  assert.equal(service.location, 'Sweden / Stockholm');
  assert.equal(confirmationTimeout.running, false);
});

test('VPN status errors remain unknown rather than disconnected and prevent blind toggles', () => {
  const { service, action } = setup();
  service.applyStatus('Cannot connect to daemon', 1, 0);
  assert.equal(service.state, 'unknown');
  assert.match(service.statusError, /daemon/);
  service.toggle();
  assert.equal(action.running, false);
  service.applyStatus('Status: Disconnected', 0, 0);
  assert.equal(service.state, 'disconnected');
  assert.equal(service.statusError, '');
});

test('VPN classifies authentication, permissions, command and confirmation timeouts', () => {
  const { service, action } = setup();
  assert.match(service.failureMessage('You are not logged in', 1), /authentication/);
  assert.match(service.failureMessage('Permission denied', 1), /permission/);
  service.toggle();
  action.running = false;
  service.finishAction(124, '');
  assert.equal(service.pending, false);
  assert.match(service.error, /timed out/);
  service.connectLocation('');
  service.expireRequest();
  assert.equal(service.state, 'unknown');
  assert.equal(service.pending, false);
  assert.match(service.error, /did not confirm/);
});

test('VPN disconnect also requires backend confirmation', () => {
  const { service, action } = setup();
  service.state = 'connected';
  service.toggle();
  assert.equal(action.command.at(-1), 'disconnect');
  action.running = false;
  service.finishAction(0, '');
  service.applyStatus('Status: Connected', 0, service.generation);
  assert.equal(service.pending, true);
  service.applyStatus('Status: Disconnected', 0, service.generation);
  assert.equal(service.pending, false);
});
