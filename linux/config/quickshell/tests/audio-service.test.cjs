const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');

const serviceSource = fs.readFileSync(path.join(__dirname, '..', 'AudioService.qml'), 'utf8');
const barSource = fs.readFileSync(path.join(__dirname, '..', 'Bar.qml'), 'utf8');
const switchSource = fs.readFileSync(path.join(__dirname, '..', 'scripts', 'audio-switch'), 'utf8');

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

});

function adjustmentState() {
  const timer = () => ({ running: false, start() { this.running = true; }, restart() { this.running = true; }, stop() { this.running = false; } });
  const globals = {
    audioApplyTimer: timer(), microphoneApplyTimer: timer(),
    audioFeedbackTimeout: timer(), microphoneFeedbackTimeout: timer(),
  };
  const node = () => ({ name: 'device', ready: true, audio: { volume: 0.5, muted: false } });
  const root = globals.root = {
    audioAvailable: true, microphoneAvailable: true,
    defaultAudioSink: node(), defaultMicrophone: node(),
    pendingAudioVolume: -1, pendingMicrophoneVolume: -1,
    audioFeedbackVolume: -1, microphoneFeedbackVolume: -1,
    audioFeedbackMute: -1, microphoneFeedbackMute: -1,
    notificationService: { showOsd: (...args) => { root.osd = args; } },
    icon: name => name, audioIcon: () => 'volume-2',
  };
  for (const name of ['setAudioVolume', 'setMicrophoneVolume', 'applyAudioVolume', 'applyMicrophoneVolume', 'cancelAudioAdjustment', 'confirmAudioAdjustment', 'toggleAudio', 'toggleMicrophone'])
    root[name] = loadBarFunction(name, globals);
  return root;
}

for (const microphone of [false, true]) {
  const label = microphone ? 'microphone' : 'output';
  const set = microphone ? 'setMicrophoneVolume' : 'setAudioVolume';
  const apply = microphone ? 'applyMicrophoneVolume' : 'applyAudioVolume';
  const current = microphone ? 'defaultMicrophone' : 'defaultAudioSink';

  test(`${label} slider coalesces drag updates against its captured node`, () => {
    const root = adjustmentState();
    root[set](65);
    root[set](70);
    root[set](85);
    assert.equal(root[current].audio.volume, 0.5);
    assert.equal(root.osd, undefined);
    root[apply]();
    assert.equal(root[current].audio.volume, 0.85);
    assert.deepEqual(root.osd, [microphone ? 'Microphone' : 'Volume', 85, microphone ? 'mic' : 'volume-2']);
  });

  test(`${label} queued adjustment cannot affect a replacement with the same name`, () => {
    const root = adjustmentState();
    const oldNode = root[current];
    root[set](85);
    root[current] = { name: oldNode.name, ready: true, audio: { volume: 0.2, muted: false } };
    root[apply]();
    assert.equal(root[current].audio.volume, 0.2);
    assert.equal(oldNode.audio.volume, 0.5);
    assert.equal(root.osd, undefined);
  });

  test(`${label} queued adjustment is discarded when the device disappears`, () => {
    const root = adjustmentState();
    const oldNode = root[current];
    root[set](85);
    root[current] = null;
    root[microphone ? 'microphoneAvailable' : 'audioAvailable'] = false;
    root[apply]();
    assert.equal(oldNode.audio.volume, 0.5);
    assert.equal(root[microphone ? 'pendingMicrophoneVolume' : 'pendingAudioVolume'], -1);
  });

  test(`${label} feedback waits until the backend reflects the adjustment`, () => {
    const root = adjustmentState();
    let volume = 0.5;
    Object.defineProperty(root[current].audio, 'volume', { get: () => volume, set() {} });
    root[set](85);
    root[apply]();
    assert.equal(root.osd, undefined);
    volume = 0.85;
    root.confirmAudioAdjustment(microphone);
    assert.equal(root.osd[1], 85);
  });
}

test('native default-device changes refresh the audio picker immediately when open', () => {
  assert.match(serviceSource, /import Quickshell\.Services\.Pipewire/);
  assert.match(serviceSource, /function onDefaultAudioSinkChanged\(\) \{\n\s+if \(service\.activePanels > 0\)\n\s+service\.refresh\(true\)/);
  assert.match(serviceSource, /function onDefaultAudioSourceChanged\(\) \{[^}]*if \(service\.activePanels > 0\)\n\s+service\.refresh\(true\)/);
});

function serviceState(overrides = {}) {
  const service = {
    outputs: [],
    inputs: [],
    defaultSink: '',
    defaultSource: '',
    pendingSink: '',
    pendingSource: '',
    error: '',
    loaded: false,
    _readSucceeded: false,
    _selectionWarning: '',
    microphoneNodes: [],
    outputSelectionTimeout: { stop() {}, restart() {} },
    inputSelectionTimeout: { stop() {}, restart() {} },
    outputIcon: loadFunction('outputIcon', {}),
    inputIcon: loadFunction('inputIcon', {}),
    get busy() { return this.pendingSink !== '' || this.pendingSource !== ''; },
    ...overrides,
  };
  service.friendlyDescription = loadFunction('friendlyDescription', {});
  service.inputDescription = loadFunction('inputDescription', { service });
  return service;
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

test('default confirmation preserves a partial stream migration warning', () => {
  const service = serviceState({
    pendingSink: 'sink-b',
    _selectionWarning: 'Some applications could not be moved.',
  });
  loadFunction('_accept', {
    service,
    setOutputProcess: { running: false },
    setInputProcess: { running: false },
  })(audioPayload([{ name: 'sink-b', description: 'Speakers' }], 'sink-b'));
  assert.equal(service.pendingSink, '');
  assert.equal(service.error, service._selectionWarning);
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
  const setDefaultSource = loadFunction('setDefaultSource', { service, setInputProcess: process, muteIntent: { initialized: false } });

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
  assert.match(serviceSource, /shellPath\("scripts\/audio-switch"\), "sink"/);
  assert.match(switchSource, /sink\) default=sink; streams=sink-inputs; move=sink-input/);
});

test('changing the input also migrates existing capture streams', () => {
  assert.match(serviceSource, /shellPath\("scripts\/audio-switch"\), "source"/);
  assert.match(switchSource, /source\) default=source; streams=source-outputs; move=source-output/);
});
