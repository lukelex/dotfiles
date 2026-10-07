const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');

const serviceSource = fs.readFileSync(path.join(__dirname, '..', 'AudioService.qml'), 'utf8');
const barSource = fs.readFileSync(path.join(__dirname, '..', 'Bar.qml'), 'utf8');

function loadFunction(name, globals) {
  const match = serviceSource.match(new RegExp(`  function ${name}\\([^]*?\\n  \\}`));
  assert.ok(match, `Missing AudioService function ${name}`);
  return vm.runInNewContext(`(${match[0]})`, globals);
}

function loadBarFunction(name, globals) {
  const match = barSource.match(new RegExp(`  function ${name}\\([^]*?\\n  \\}`));
  assert.ok(match, `Missing Bar function ${name}`);
  return vm.runInNewContext(`(${match[0]})`, globals);
}

test('bar audio volume and mute state use the live PipeWire default sink', () => {
  assert.match(barSource, /import Quickshell\.Services\.Pipewire/);
  assert.match(barSource, /PwObjectTracker \{\n\s+objects: \[Pipewire\.defaultAudioSink, Pipewire\.defaultAudioSource\]/);
  assert.match(barSource, /readonly property real audioVolume: root\.audioAvailable \? root\.defaultAudioSink\.audio\.volume \* 100 : 0/);
  assert.doesNotMatch(barSource, /id: audioStatus|interval: 1000[\s\S]{0,100}audioStatus/);

  const root = {
    audioAvailable: true,
    audioMuted: false,
    pendingAudioVolume: -1,
    notificationService: { showOsd: (...args) => { root.osd = args; } },
    audioIcon: () => 'volume-2',
  };
  const audioSet = { value: 0, running: false };
  const audioToggle = { running: false };
  const controlRefreshTimer = { restart() {} };
  root.applyAudioVolume = loadBarFunction('applyAudioVolume', { root, audioSet });
  loadBarFunction('setAudioVolume', { root, audioSet })(65);
  assert.deepEqual(audioSet, { value: 65, running: true });
  assert.equal(root.osd, undefined, 'Feedback waits for the backend rather than announcing the request');

  loadBarFunction('setAudioVolume', { root, audioSet })(70);
  loadBarFunction('setAudioVolume', { root, audioSet })(85);
  assert.equal(audioSet.value, 65, 'An in-flight command retains its arguments');
  assert.equal(root.pendingAudioVolume, 85, 'The latest drag value survives competing updates');
  audioSet.running = false;
  root.applyAudioVolume();
  assert.equal(audioSet.value, 85);
  assert.equal(root.pendingAudioVolume, -1);

  loadBarFunction('toggleAudio', { root, audioToggle, controlRefreshTimer })();
  assert.equal(audioToggle.running, true);
});

test('native default-device changes refresh the audio picker immediately when open', () => {
  assert.match(serviceSource, /import Quickshell\.Services\.Pipewire/);
  assert.match(serviceSource, /function onDefaultAudioSinkChanged\(\) \{\n\s+if \(service\.activePanels > 0\)\n\s+service\.refresh\(true\)/);
  assert.match(serviceSource, /function onDefaultAudioSourceChanged\(\) \{\n\s+if \(service\.activePanels > 0\)\n\s+service\.refresh\(true\)/);
});

function serviceState(overrides = {}) {
  return {
    outputs: [],
    inputs: [],
    defaultSink: '',
    defaultSource: '',
    pendingSink: '',
    pendingSource: '',
    error: '',
    loaded: false,
    _readSucceeded: false,
    outputSelectionTimeout: { stop() {}, restart() {} },
    inputSelectionTimeout: { stop() {}, restart() {} },
    outputIcon: loadFunction('outputIcon', {}),
    inputIcon: loadFunction('inputIcon', {}),
    inputDescription: loadFunction('inputDescription', {}),
    get busy() { return this.pendingSink !== '' || this.pendingSource !== ''; },
    ...overrides,
  };
}

function audioPayload(sinks, defaultSink, sources = [], defaultSource = '') {
  return `${JSON.stringify(sinks)}\n__QUICKSHELL_DEFAULT_SINK__\n${defaultSink}`
    + `\n__QUICKSHELL_INPUTS__\n${JSON.stringify(sources)}`
    + `\n__QUICKSHELL_DEFAULT_SOURCE__\n${defaultSource}\n`;
}

test('output discovery parses every sink and confirms the selected default', () => {
  let timeoutStopped = false;
  const service = serviceState({
    pendingSink: 'sink-b',
    outputSelectionTimeout: { stop() { timeoutStopped = true; }, restart() {} },
  });
  const accept = loadFunction('_accept', {
    service,
    setOutputProcess: { running: false },
    setInputProcess: { running: false },
  });

  accept(audioPayload([
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
    setInputProcess: { running: false },
  })('not-json');

  assert.equal(service.outputs, oldOutputs);
  assert.equal(service._readSucceeded, false);
  assert.equal(service.error, 'Audio devices are unavailable.');
});

test('input discovery excludes monitor sources and labels the active mic port', () => {
  const service = serviceState();
  loadFunction('_accept', {
    service,
    setOutputProcess: { running: false },
    setInputProcess: { running: false },
  })(audioPayload([], '', [
    {
      name: 'alsa_output.pci.monitor',
      description: 'Monitor of speakers',
      properties: { 'device.class': 'monitor', 'media.class': 'Audio/Sink' },
    },
    {
      name: 'alsa_input.internal',
      description: 'Built-in Audio Analog Stereo',
      properties: { 'media.class': 'Audio/Source' },
      ports: [{ name: 'mic', description: 'Internal Microphone', type: 'Mic' }],
      active_port: 'mic',
    },
  ], 'alsa_input.internal'));

  assert.deepEqual([...service.inputs.map(input => input.name)], ['alsa_input.internal']);
  assert.match(service.inputs[0].description, /Internal Microphone/);
  assert.equal(service.inputs[0].iconName, 'mic');
  assert.equal(service.defaultSource, 'alsa_input.internal');
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

test('input icons distinguish Bluetooth, headset, USB, and built-in microphones', () => {
  const inputIcon = loadFunction('inputIcon', {});

  assert.equal(inputIcon({ name: 'bluez_input.headset', properties: { 'device.bus': 'bluetooth' } }), 'bluetooth');
  assert.equal(inputIcon({ description: 'USB Gaming Headset' }), 'headphones');
  assert.equal(inputIcon({ name: 'alsa_input.usb-microphone', properties: { 'device.bus': 'usb' } }), 'usb');
  assert.equal(inputIcon({ name: 'alsa_input.pci-internal' }), 'mic');
});

test('sink selection rejects stale, current, and competing requests', () => {
  const service = serviceState({
    outputs: [{ name: 'sink-a' }, { name: 'sink-b' }],
    defaultSink: 'sink-a',
  });
  const process = { running: false };
  const timeout = { restart() { this.restarted = true; }, stop() {} };
  service.outputSelectionTimeout = timeout;
  const setDefaultSink = loadFunction('setDefaultSink', { service, setOutputProcess: process });

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

test('source selection validates devices and tracks pending state', () => {
  const service = serviceState({
    inputs: [{ name: 'mic-internal' }, { name: 'mic-usb' }],
    defaultSource: 'mic-internal',
  });
  const process = { running: false };
  const timeout = { restart() { this.restarted = true; }, stop() {} };
  service.inputSelectionTimeout = timeout;
  const setDefaultSource = loadFunction('setDefaultSource', { service, setInputProcess: process });

  setDefaultSource('missing');
  setDefaultSource('mic-internal');
  assert.equal(service.pendingSource, '');

  setDefaultSource('mic-usb');
  assert.equal(service.pendingSource, 'mic-usb');
  assert.equal(service._requestedSource, 'mic-usb');
  assert.equal(process.running, true);
  assert.equal(timeout.restarted, true);
});

test('changing the output also migrates existing playback streams', () => {
  assert.match(serviceSource, /pactl set-default-sink \\"\$sink\\"/);
  assert.match(serviceSource, /pactl move-sink-input \\"\$input\\" \\"\$sink\\"/);
});

test('changing the input also migrates existing capture streams', () => {
  assert.match(serviceSource, /pactl set-default-source \\"\$source\\"/);
  assert.match(serviceSource, /pactl move-source-output \\"\$output\\" \\"\$source\\"/);
});
