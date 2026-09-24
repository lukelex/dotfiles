const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');

const serviceSource = fs.readFileSync(path.join(__dirname, '..', 'AudioService.qml'), 'utf8');

function loadFunction(name, globals) {
  const match = serviceSource.match(new RegExp(`  function ${name}\\([^]*?\\n  \\}`));
  assert.ok(match, `Missing AudioService function ${name}`);
  return vm.runInNewContext(`(${match[0]})`, globals);
}

function serviceState(overrides = {}) {
  return {
    outputs: [],
    defaultSink: '',
    pendingSink: '',
    error: '',
    loaded: false,
    _readSucceeded: false,
    selectionTimeout: { stop() {} },
    outputIcon: loadFunction('outputIcon', {}),
    ...overrides,
  };
}

function outputPayload(sinks, defaultSink) {
  return `${JSON.stringify(sinks)}\n__QUICKSHELL_DEFAULT_SINK__\n${defaultSink}\n`;
}

test('output discovery parses every sink and confirms the selected default', () => {
  let timeoutStopped = false;
  const service = serviceState({
    pendingSink: 'sink-b',
    selectionTimeout: { stop() { timeoutStopped = true; } },
  });
  const accept = loadFunction('_accept', {
    service,
    setOutputProcess: { running: false },
  });

  accept(outputPayload([
    { name: 'sink-b', description: 'USB Headphones' },
    { name: 'sink-a', description: 'Built-in Audio' },
  ], 'sink-b'));

  assert.deepEqual([...service.outputs.map(output => output.name)], ['sink-a', 'sink-b']);
  assert.equal(service.defaultSink, 'sink-b');
  assert.equal(service.pendingSink, '');
  assert.equal(service.loaded, true);
  assert.equal(service._readSucceeded, true);
  assert.equal(timeoutStopped, true);
});

test('output discovery leaves existing devices intact when the response is malformed', () => {
  const oldOutputs = [{ name: 'sink-a', description: 'Built-in Audio' }];
  const service = serviceState({ outputs: oldOutputs });
  loadFunction('_accept', {
    service,
    setOutputProcess: { running: false },
  })('not-json');

  assert.equal(service.outputs, oldOutputs);
  assert.equal(service._readSucceeded, false);
  assert.equal(service.error, 'Output devices are unavailable.');
});

test('output polling remains active only for open panels', () => {
  const service = serviceState({ activePanels: 0 });
  const panelOpened = loadFunction('panelOpened', { service });
  const panelClosed = loadFunction('panelClosed', { service });

  panelOpened();
  panelOpened();
  assert.equal(service.activePanels, 2);
  panelClosed();
  panelClosed();
  panelClosed();
  assert.equal(service.activePanels, 0);
});

test('output icons distinguish Bluetooth, display, headphones, USB, and built-in audio', () => {
  const outputIcon = loadFunction('outputIcon', {});

  assert.equal(outputIcon({ name: 'bluez_output.headphones', properties: { 'device.bus': 'bluetooth' } }), 'bluetooth');
  assert.equal(outputIcon({ name: 'alsa_output.hdmi-stereo', description: 'HDMI Stereo' }), 'monitor');
  assert.equal(outputIcon({ description: 'Wired Headphones' }), 'headphones');
  assert.equal(outputIcon({ name: 'alsa_output.usb-audio', properties: { 'device.bus': 'usb' } }), 'usb');
  assert.equal(outputIcon({ name: 'alsa_output.pci-analog-stereo' }), 'speaker');
});

test('sink selection rejects stale, current, and competing requests', () => {
  const service = serviceState({
    outputs: [{ name: 'sink-a' }, { name: 'sink-b' }],
    defaultSink: 'sink-a',
  });
  const process = { running: false };
  const timeout = { restart() { this.restarted = true; } };
  const setDefaultSink = loadFunction('setDefaultSink', { service, setOutputProcess: process, selectionTimeout: timeout });

  setDefaultSink('missing');
  setDefaultSink('sink-a');
  assert.equal(service.pendingSink, '');

  setDefaultSink('sink-b');
  assert.equal(service.pendingSink, 'sink-b');
  assert.equal(service._requestedSink, 'sink-b');
  assert.equal(process.running, true);
  assert.equal(timeout.restarted, true);

  setDefaultSink('sink-a');
  assert.equal(service.pendingSink, 'sink-b');
});

test('changing the output also migrates existing playback streams', () => {
  assert.match(serviceSource, /pactl set-default-sink \\"\$sink\\"/);
  assert.match(serviceSource, /pactl move-sink-input \\"\$input\\" \\"\$sink\\"/);
});
