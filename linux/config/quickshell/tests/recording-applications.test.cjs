const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');

const source = fs.readFileSync(path.join(__dirname, '..', 'AudioService.qml'), 'utf8');
const match = source.match(/  function collectRecordingApplications\([^]*?\n  \}/);
const PwNodeType = { AudioSource: 1, AudioInStream: 2, AudioSink: 3 };
const PwLinkState = { Active: 1, Paused: 2 };
const service = { inputs: [{ name: 'tonor', description: 'TONOR microphone' }], friendlyDescription: () => '' };
const collect = vm.runInNewContext(`(${match[0]})`, { service, PwNodeType, PwLinkState });
const input = (name = 'tonor', muted = false) => ({ name, ready: true, type: PwNodeType.AudioSource, audio: { muted }, description: name });
const stream = (id, properties = {}) => ({ id, name: `stream-${id}`, ready: true, type: PwNodeType.AudioInStream, properties });
const link = (source, target, state = PwLinkState.Active) => ({ source, target, state });

test('active recording reports its linked input rather than the default microphone', () => {
  const result = collect([link(input('headset', true), stream(1, { 'application.name': 'Meeting app' }))]);
  assert.equal(result.length, 1);
  assert.equal(result[0].name, 'Meeting app');
  assert.equal(result[0].inputName, 'headset');
  assert.equal(result[0].muted, true, 'Recording on a muted input remains visible');
});

test('paused, unready, and playback-monitor connections are not microphone use', () => {
  const mic = input();
  const target = stream(1);
  const unready = stream(2);
  unready.ready = false;
  const monitor = { ...mic, type: PwNodeType.AudioSink };
  assert.equal(collect([link(mic, target, PwLinkState.Paused), link(mic, unready), link(monitor, target)]).length, 0);
});

test('level meters and the native shell peak detector are excluded', () => {
  const properties = [
    { 'application.name': 'Quickshell Peak Detect' },
    { 'stream.monitor': true }, { 'stream.monitor': 'true' },
    { 'resample.peaks': true }, { 'resample.peaks': 'true' },
    { 'media.category': 'Monitor' },
  ];
  assert.equal(collect(properties.map((props, id) => link(input(), stream(id, props)))).length, 0);
});

test('multiple streams aggregate per application and input without counting duplicate links', () => {
  const mic = input();
  const first = stream(1, { 'application.name': 'Browser' });
  const second = stream(2, { 'application.name': 'Browser' });
  const result = collect([link(mic, first), link(mic, first), link(mic, second), link(input('headset'), first)]);
  assert.equal(result.length, 2);
  const tonor = result.find(app => app.inputName === 'tonor');
  assert.equal(tonor.streamCount, 2);
  assert.equal(tonor.inputDescription, 'TONOR microphone');
});

test('recording list updates on pause, mute and removal with stable name ordering', () => {
  const mic = input();
  const groups = [link(mic, stream(1, { 'application.process.binary': 'z-recorder' })),
    link(mic, stream(2, { 'application.name': 'A meeting' }))];
  assert.deepEqual(Array.from(collect(groups), app => app.name), ['A meeting', 'z-recorder']);
  mic.audio.muted = true;
  assert.ok(collect(groups).every(app => app.muted));
  groups[1].state = PwLinkState.Paused;
  assert.equal(collect(groups).length, 1);
  groups.pop();
  groups.pop();
  assert.equal(collect(groups).length, 0);
});
