const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');

const source = fs.readFileSync(path.join(__dirname, '../ConnectivityService.qml'), 'utf8');

function setup() {
  const calls = [];
  const device = {};
  const current = { name: 'Current', device, connected: true, signalStrength: 0.2 };
  const target = { name: 'Saved', device, known: true, connected: false,
    stateChanging: false, signalStrength: 0.6, connect() { calls.push('connect'); } };
  const service = {
    activeNetwork: current, wifiSsid: current.name, wifiStrength: 0.2,
    wifiAvailable: true, wifiEnabled: true, wifiHardwareEnabled: true, wifiConnecting: false,
    savedNetworks: [current, target], _wifiSuggestionShown: false,
    _wifiSuggestion: { running: false }, _wifiSuggestionConnecting: false,
    _state: { pending: false }, _connectionTimeout: { restart() {}, stop() {} },
  };
  const context = vm.createContext({ service,
    ConnectionState: { Connecting: 1 },
    Quickshell: { env: () => '/home/test', execDetached: command => calls.push(command) },
  });
  Object.defineProperty(service, 'wifiWeak', {
    get: () => vm.runInContext(source.match(/readonly property bool wifiWeak: ([^]*?)\n  property/)[1], context),
  });
  for (const name of ['betterWifi', 'wifiNotificationText', 'suggestBetterWifi',
    'finishWifiSuggestion', 'notifyWifiSwitchFailure', 'connectNetwork', '_finishConnection']) {
    const match = source.match(new RegExp(`^( +)function ${name}\\([^]*?\\n\\1\\}`, 'm'));
    assert.ok(match, `Missing ${name}`);
    const javascript = match[0].replace(/^[^{]+/, signature => signature.replace(/:\s*\w+/g, ''));
    service[name] = vm.runInContext(`(${javascript})`, context);
  }
  function click(action = 'switch', exitCode = 0) {
    service._wifiSuggestionAction = action;
    service._wifiSuggestion.running = false;
    service.finishWifiSuggestion(exitCode, 0);
  }
  return { service, current, target, calls, click, context };
}

test('weak Wi-Fi offers the strongest saved available network without connecting automatically', () => {
  const { service, target, calls } = setup();
  service.savedNetworks.push({ ...target, name: 'Stronger', signalStrength: 0.8 });
  service.suggestBetterWifi();
  assert.equal(service._wifiSuggestionTarget.name, 'Stronger');
  assert.equal(service._wifiSuggestion.running, true);
  assert.ok(service._wifiSuggestion.command.includes('switch=Switch to Stronger'));
  assert.equal(service._wifiSuggestion.command[service._wifiSuggestion.command.indexOf('-t') + 1], '0');
  assert.ok(service._wifiSuggestion.command.includes('stay=Keep current Wi-Fi'));
  assert.deepEqual(calls, []);
  service._wifiSuggestion.running = false;
  service.suggestBetterWifi();
  assert.equal(service._wifiSuggestion.running, false, 'Only one offer per weak episode');
});

test('no offer for healthy, unknown, disconnected or disabled Wi-Fi', () => {
  for (const patch of [
    { wifiStrength: 0.25 }, { wifiStrength: 0 }, { wifiStrength: NaN },
    { activeNetwork: null }, { wifiEnabled: false }, { wifiHardwareEnabled: false },
    { wifiAvailable: false }, { wifiConnecting: true },
  ]) {
    const { service } = setup();
    Object.assign(service, patch);
    service.suggestBetterWifi();
    assert.equal(service._wifiSuggestion.running, false);
  }
});

test('alternatives must be saved, available, meaningfully stronger and on the active adapter', () => {
  for (const patch of [
    { known: false }, { signalStrength: 0 }, { signalStrength: 0.34 },
    { signalStrength: NaN }, { signalStrength: 1.1 }, { connected: true },
    { stateChanging: true }, { device: {} }, { name: 'Current' },
  ]) {
    const { service, target } = setup();
    Object.assign(target, patch);
    service.suggestBetterWifi();
    assert.equal(service._wifiSuggestion.running, false);
    assert.equal(service._wifiSuggestionShown, false, 'A later eligible network can still prompt');
  }
});

test('notification action activates the native saved profile without an explicit disconnect', () => {
  const { service, target, calls, click } = setup();
  service.suggestBetterWifi();
  click();
  assert.deepEqual(calls, ['connect']);
  assert.equal(service._state.requestedNetwork, target);
  assert.equal(service._state.pending, true);
  service._finishConnection('');
  assert.equal(service._wifiSuggestionConnecting, false);
  assert.deepEqual(calls, ['connect']);
});

test('dismissed, failed and stale actions never switch Wi-Fi', () => {
  for (const change of [
    ({ click }) => click(''),
    ({ click }) => click('stay'),
    ({ click }) => click('switch', 1),
    ({ service, click }) => { service.activeNetwork = {}; click(); },
    ({ service, click }) => { service.savedNetworks = []; click(); },
    ({ service, click }) => { service.wifiStrength = 0.6; click(); },
    ({ service, click }) => { service.wifiConnecting = true; click(); },
    ({ target, click }) => { target.known = false; click(); },
    ({ target, click }) => { target.signalStrength = 0; click(); },
  ]) {
    const fixture = setup();
    fixture.service.suggestBetterWifi();
    change(fixture);
    assert.deepEqual(fixture.calls, []);
    assert.equal(fixture.service._wifiSuggestionTarget, null);
    assert.equal(fixture.service._wifiSuggestionSource, null);
  }
});

test('switch errors notify once and network names cannot inject body markup or shell commands', () => {
  const { service, target, calls, click } = setup();
  target.name = '<Saved & "network">; echo nope';
  service.suggestBetterWifi();
  assert.equal(service._wifiSuggestion.command.at(-1),
    'Current has a weak signal. Saved network &lt;Saved &amp; "network"&gt;; echo nope has a stronger signal.');
  click();
  service._finishConnection('Credentials <invalid>');
  assert.equal(calls.length, 2);
  assert.equal(calls[1].at(-1), 'Credentials &lt;invalid&gt;');
  service._finishConnection('Another event');
  assert.equal(calls.length, 2);
});

test('background scans and delayed checks run only for weakness, with recovery hysteresis', () => {
  assert.match(source, /value: service\.wifiEnabled && \(service\.wifiScanningEnabled \|\| service\.wifiWeak\)/);
  assert.match(source, /interval: 15000\s+repeat: true\s+running: service\.wifiWeak && !service\._wifiSuggestionShown/);
  const { service, context } = setup();
  const handler = source.match(/onWifiStrengthChanged: (\{[^]*?\n  \})/)[1];
  service._wifiSuggestionShown = true;
  service.wifiStrength = 0.26;
  vm.runInContext(handler, context);
  assert.equal(service._wifiSuggestionShown, true);
  service.wifiStrength = 0.35;
  vm.runInContext(handler, context);
  assert.equal(service._wifiSuggestionShown, false);
  assert.match(source, /onActiveNetworkChanged: service\._wifiSuggestionShown = false/);
});

test('synchronous connection failures produce only one error notification', () => {
  const { service, target, calls, click } = setup();
  target.connect = () => { throw new Error('Activation rejected'); };
  service.suggestBetterWifi();
  click();
  assert.equal(calls.length, 1);
  assert.match(calls[0].at(-1), /Activation rejected/);
  assert.equal(service._wifiSuggestionConnecting, false);
});
