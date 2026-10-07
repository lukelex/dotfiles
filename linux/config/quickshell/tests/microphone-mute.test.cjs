const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');

const source = fs.readFileSync(path.join(__dirname, '..', 'AudioService.qml'), 'utf8');
const node = (muted = false) => ({ ready: true, audio: { muted } });

function setup(intent = { initialized: false, muted: false, allInputs: false }) {
  const first = node();
  const Pipewire = { defaultAudioSource: first };
  const timeout = { running: false, restart() { this.running = true; }, stop() { this.running = false; } };
  const service = {
    _muteIntentReady: true, _muteSource: null, _mutePending: false,
    microphoneNodes: [first], microphoneMuteError: '',
  };
  const globals = { service, Pipewire, muteIntent: intent, muteConfirmationTimeout: timeout };
  for (const name of ['syncMicrophoneMute', 'observeMicrophoneMute', 'setMicrophoneMuted', 'muteAllMicrophones', 'confirmMicrophoneMute']) {
    const match = source.match(new RegExp(`  function ${name}\\([^]*?\\n  \\}`));
    assert.ok(match, `Missing ${name}`);
    service[name] = vm.runInNewContext(`(${match[0]})`, globals);
  }
  service.syncMicrophoneMute();
  function select(next) {
    Pipewire.defaultAudioSource = next;
    service._muteSource = null;
    service._mutePending = false;
    if (next && !service.microphoneNodes.includes(next)) service.microphoneNodes.push(next);
    service.syncMicrophoneMute();
  }
  return { service, intent, first, select, timeout, Pipewire };
}

test('initial startup adopts the selected microphone state', () => {
  const state = setup();
  assert.equal(state.intent.initialized, true);
  assert.equal(state.first.audio.muted, false);
});

for (const muted of [false, true]) {
  test(`selected microphone intent ${muted} follows device switches and disconnect gaps`, () => {
    const state = setup();
    state.service.setMicrophoneMuted(muted);
    state.service.observeMicrophoneMute(state.first);
    state.select(null);
    const replacement = node(!muted);
    state.select(replacement);
    assert.equal(replacement.audio.muted, muted);
    assert.equal(state.intent.muted, muted);
    state.service.observeMicrophoneMute(replacement);
    assert.equal(state.service._mutePending, false);
    assert.equal(state.timeout.running, false);
  });
}

test('mute intent waits for a replacement node to become ready', () => {
  const state = setup({ initialized: true, muted: true, allInputs: false });
  const replacement = node();
  replacement.ready = false;
  state.select(replacement);
  assert.equal(replacement.audio.muted, false);
  replacement.ready = true;
  state.service.syncMicrophoneMute();
  assert.equal(replacement.audio.muted, true);
});

test('keyboard and external selected-microphone changes become the new intent', () => {
  const state = setup();
  state.first.audio.muted = true;
  state.service.observeMicrophoneMute(state.first);
  const replacement = node();
  state.select(replacement);
  assert.equal(replacement.audio.muted, true);
});

test('unrelated microphone mute changes do not override selected-microphone intent', () => {
  const state = setup();
  const other = node(true);
  state.service.microphoneNodes.push(other);
  state.service.observeMicrophoneMute(other);
  assert.equal(state.intent.muted, false);
});

test('stale backend state during a carried mute cannot overwrite the intent', () => {
  const state = setup({ initialized: true, muted: true, allInputs: false });
  const replacement = node();
  let muted = false;
  Object.defineProperty(replacement.audio, 'muted', { get: () => muted, set() {} });
  state.select(replacement);
  state.service.observeMicrophoneMute(replacement);
  assert.equal(state.intent.muted, true);
  assert.equal(state.service._mutePending, true);
  muted = true;
  state.service.observeMicrophoneMute(replacement);
  assert.equal(state.service._mutePending, false);
});

test('all-input mute includes newly arrived microphones and releases on selected unmute', () => {
  const state = setup();
  const other = node();
  state.service.microphoneNodes.push(other);
  state.service.muteAllMicrophones();
  assert.equal(state.first.audio.muted, true);
  assert.equal(other.audio.muted, true);
  state.service.observeMicrophoneMute(state.first);
  const arrived = node();
  state.service.microphoneNodes.push(arrived);
  state.service.syncMicrophoneMute();
  assert.equal(arrived.audio.muted, true);
  state.service.setMicrophoneMuted(false);
  assert.equal(state.intent.allInputs, false);
  assert.equal(state.first.audio.muted, false);
  assert.equal(other.audio.muted, true, 'Unmuting selected input does not unmute other inputs');
  const later = node();
  state.service.microphoneNodes.push(later);
  state.service.syncMicrophoneMute();
  assert.equal(later.audio.muted, false);
});

test('restored reload intent is applied instead of adopting a replacement state', () => {
  const state = setup({ initialized: true, muted: true, allInputs: true });
  assert.equal(state.first.audio.muted, true);
  assert.equal(state.intent.allInputs, true);
  assert.match(source, /PersistentProperties/);
});
