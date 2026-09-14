const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');

const source = fs.readFileSync(path.join(__dirname, '../ConnectivityService.qml'), 'utf8');
const ConnectionState = { Disconnected: 0, Connecting: 1, Connected: 2 };
const BluetoothAdapterState = { Blocked: 0 };

function serviceForTest() {
  const calls = { connect: 0, restart: 0, stop: 0, power: [] };
  Object.defineProperties(calls, {
    ethernetConnect: { value: 0, writable: true },
    ethernetDisconnect: { value: 0, writable: true },
    autoconnect: { value: [], writable: true },
  });
  const network = {
    known: true,
    connected: false,
    state: ConnectionState.Disconnected,
    connect() { calls.connect++; },
    disconnect() { assert.fail('Activation must not disconnect a network'); },
  };
  const adapter = {
    state: BluetoothAdapterState.Blocked,
    get enabled() { return false; },
    set enabled(value) { calls.power.push(['bluetooth', value]); },
  };
  const wiredNetwork = {
    known: true,
    connected: false,
    state: ConnectionState.Disconnected,
    connect() { calls.ethernetConnect++; },
  };
  const wiredDevice = {
    connected: true,
    state: ConnectionState.Connected,
    set autoconnect(value) { calls.autoconnect.push(value); },
    disconnect() { calls.ethernetDisconnect++; },
  };
  const service = {
    wifiAvailable: true,
    wifiEnabled: true,
    wifiHardwareEnabled: true,
    bluetoothAvailable: true,
    savedNetworks: [network],
    activeNetwork: { connected: true, disconnect: network.disconnect },
    ethernetAvailable: true,
    _wiredDevices: [wiredDevice],
    _wiredNetworks: [wiredNetwork],
    _state: {
      requestedNetwork: null, pending: false, sawConnecting: false,
      wifiError: '', wifiErrorReason: -1, ethernetError: '', bluetoothError: '',
    },
    _connectionTimeout: {
      restart() { calls.restart++; },
      stop() { calls.stop++; },
    },
  };
  // Only extracted JavaScript runs; no QML imports, native radios or real timers.
  const context = vm.createContext({
    service,
    ConnectionState,
    ConnectionFailReason: { toString: reason => `Connection failure ${reason}` },
    BluetoothAdapterState,
    Bluetooth: { adapters: { values: [adapter] } },
    Networking: {
      get wifiEnabled() { return service.wifiEnabled; },
      set wifiEnabled(value) { calls.power.push(['wifi', value]); },
    },
  });
  for (const name of ['connectNetwork', '_finishConnection', 'setWifiEnabled', 'setEthernetEnabled',
    'setBluetoothEnabled', 'onConnectionFailed', 'onStateChanged']) {
    const match = source.match(new RegExp(`^( +)function ${name}\\([^]*?\\n\\1\\}`, 'm'));
    assert.ok(match, `Missing QML function ${name}`);
    const javascript = match[0].replace(/^[^{]+/, signature =>
      signature.replace(/:\s*\w+/g, ''));
    service[name] = vm.runInContext(`(${javascript})`, context);
  }
  return { service, network, wiredNetwork, wiredDevice, calls };
}

test('Ethernet toggle disables autoconnect and disconnects active adapters', () => {
  const { service, calls } = serviceForTest();
  assert.equal(service.setEthernetEnabled(false), true);
  assert.deepEqual(calls.autoconnect, [false]);
  assert.equal(calls.ethernetDisconnect, 1);
  assert.equal(calls.ethernetConnect, 0);
});

test('Ethernet toggle enables autoconnect and activates an available profile', () => {
  const { service, wiredDevice, calls } = serviceForTest();
  wiredDevice.connected = false;
  wiredDevice.state = ConnectionState.Disconnected;
  assert.equal(service.setEthernetEnabled(true), true);
  assert.deepEqual(calls.autoconnect, [true]);
  assert.equal(calls.ethernetConnect, 1);
  assert.equal(calls.ethernetDisconnect, 0);
});

test('saved network activation does not disconnect the active network or change power', () => {
  const { service, network, calls } = serviceForTest();
  service._state.wifiError = 'Previous failure';
  service._state.wifiErrorReason = 7;
  assert.equal(service.connectNetwork(network), true);
  assert.equal(calls.connect, 1);
  assert.equal(calls.restart, 1);
  assert.equal(calls.stop, 0);
  assert.deepEqual(calls.power, []);
  assert.equal(service.activeNetwork.connected, true);
  assert.equal(service._state.requestedNetwork, network);
  assert.equal(service._state.pending, true);
  assert.equal(service._state.sawConnecting, false);
  assert.equal(service._state.wifiError, '');
  assert.equal(service._state.wifiErrorReason, -1);
});

test('pending requests reject duplicate and competing activation without altering state', () => {
  const { service, network, calls } = serviceForTest();
  service.connectNetwork(network);
  service._state.wifiError = 'Keep pending error';
  service._state.wifiErrorReason = 7;
  const state = { ...service._state };
  const other = { ...network, connect() { assert.fail('Competing activation'); } };
  service.savedNetworks.push(other);
  for (const requested of [network, other, null]) {
    assert.equal(service.connectNetwork(requested), false);
    assert.deepEqual(service._state, state);
  }
  assert.equal(calls.connect, 1);
  assert.equal(calls.restart, 1);
  assert.equal(calls.stop, 0);
});

for (const scenario of ['unavailable', 'disabled', 'hardware blocked', 'missing', 'not saved', 'unknown']) {
  test(`activation rejects ${scenario} networks without native side effects`, () => {
    const { service, network, calls } = serviceForTest();
    if (scenario === 'unavailable') service.wifiAvailable = false;
    if (scenario === 'disabled') service.wifiEnabled = false;
    if (scenario === 'hardware blocked') service.wifiHardwareEnabled = false;
    if (scenario === 'not saved') service.savedNetworks = [];
    if (scenario === 'unknown') network.known = false;
    service._state.wifiError = 'Previous failure';
    service._state.wifiErrorReason = 7;
    assert.equal(service.connectNetwork(scenario === 'missing' ? null : network), false);
    assert.equal(service._state.wifiError, ['unavailable', 'disabled', 'hardware blocked'].includes(scenario)
      ? 'Wi-Fi is unavailable, disabled or hardware blocked.'
      : 'The saved Wi-Fi network is no longer available.');
    assert.equal(service._state.wifiErrorReason, -1);
    assert.equal(service._state.requestedNetwork, null);
    assert.equal(service._state.pending, false);
    assert.deepEqual(calls, { connect: 0, restart: 0, stop: 0, power: [] });
  });
}

test('already connected networks succeed without activation or a timer', () => {
  const { service, network, calls } = serviceForTest();
  network.connected = true;
  network.state = ConnectionState.Connected;
  assert.equal(service.connectNetwork(network), true);
  assert.equal(service._state.pending, false);
  assert.deepEqual(calls, { connect: 0, restart: 0, stop: 0, power: [] });
});

test('already connecting networks are tracked without activating again', () => {
  const { service, network, calls } = serviceForTest();
  network.state = ConnectionState.Connecting;
  assert.equal(service.connectNetwork(network), true);
  assert.equal(service._state.pending, true);
  assert.equal(service._state.sawConnecting, true);
  assert.equal(calls.connect, 0);
  assert.equal(calls.restart, 1);
});

test('async state changes keep the request pending until connection succeeds', async () => {
  const { service, network, calls } = serviceForTest();
  service.connectNetwork(network);
  await Promise.resolve();
  service.onStateChanged();
  assert.equal(service._state.pending, true);
  network.state = ConnectionState.Connecting;
  service.onStateChanged();
  assert.equal(service._state.sawConnecting, true);
  assert.equal(service._state.pending, true);
  assert.equal(calls.stop, 0);
  network.state = ConnectionState.Connected;
  service.onStateChanged();
  assert.equal(service._state.pending, false);
  assert.equal(service._state.wifiError, '');
  assert.equal(service._state.wifiErrorReason, -1);
  assert.equal(calls.stop, 1);
});

test('async failure preserves its reason through later state notifications and resets on retry', async () => {
  const { service, network, calls } = serviceForTest();
  service.connectNetwork(network);
  await Promise.resolve();
  service.onConnectionFailed(7);
  assert.equal(service._state.pending, false);
  assert.equal(service._state.wifiError, 'Connection failure 7');
  assert.equal(service._state.wifiErrorReason, 7);
  for (const state of [ConnectionState.Disconnected, ConnectionState.Connected]) {
    network.state = state;
    service.onStateChanged();
    assert.equal(service._state.wifiError, 'Connection failure 7');
    assert.equal(service._state.wifiErrorReason, 7);
  }
  assert.equal(calls.stop, 1);
  network.state = ConnectionState.Disconnected;
  assert.equal(service.connectNetwork(network), true);
  assert.equal(service._state.wifiError, '');
  assert.equal(service._state.wifiErrorReason, -1);
  assert.equal(calls.connect, 2);
});

test('disconnecting after a connecting state finishes with an error', () => {
  const { service, network, calls } = serviceForTest();
  service.connectNetwork(network);
  network.state = ConnectionState.Connecting;
  service.onStateChanged();
  network.state = ConnectionState.Disconnected;
  service.onStateChanged();
  assert.equal(service._state.pending, false);
  assert.equal(service._state.wifiError, 'Wi-Fi connection ended before it was established.');
  assert.equal(service._state.wifiErrorReason, -1);
  assert.equal(calls.stop, 1);
});

test('synchronous activation exceptions finish the request and stop its timer', () => {
  const { service, network, calls } = serviceForTest();
  network.connect = () => { throw new Error('Activation rejected'); };
  assert.equal(service.connectNetwork(network), false);
  assert.equal(service._state.pending, false);
  assert.equal(service._state.wifiError, 'Error: Activation rejected');
  assert.equal(service._state.wifiErrorReason, -1);
  assert.equal(calls.restart, 1);
  assert.equal(calls.stop, 1);
});

test('hardware blocked Wi-Fi cannot be powered on', () => {
  const { service, calls } = serviceForTest();
  service.wifiHardwareEnabled = false;
  service._state.wifiErrorReason = 7;
  assert.equal(service.setWifiEnabled(true), false);
  assert.equal(service._state.wifiError, 'Wi-Fi is hardware blocked.');
  assert.equal(service._state.wifiErrorReason, -1);
  assert.deepEqual(calls.power, []);
});

test('blocked Bluetooth adapters cannot be powered on', () => {
  const { service, calls } = serviceForTest();
  assert.equal(service.setBluetoothEnabled(true), false);
  assert.equal(service._state.bluetoothError, 'A Bluetooth adapter is blocked.');
  assert.deepEqual(calls.power, []);
});
