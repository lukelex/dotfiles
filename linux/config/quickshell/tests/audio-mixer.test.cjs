const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const vm = require('node:vm');
const { spawnSync } = require('node:child_process');
const { test } = require('node:test');

const helper = path.resolve(__dirname, '../audio-mixer.py');
const source = fs.readFileSync(path.resolve(__dirname, '../AudioMixer.qml'), 'utf8');
const volume = () => ({ 'front-left': { value: 32768 }, 'front-right': { value: 16384 } });
function fixture(t) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'audio-mixer-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  const state = {
    sinks: [{ index: 10, name: 'speakers', description: 'Speakers', volume: volume(), mute: false,
      properties: { 'object.serial': '100' }, active_port: 'speaker', ports: [
        { name: 'speaker', description: 'Speakers', availability: 'available' },
        { name: 'headphones', description: 'Headphones', availability: 'unknown' },
        { name: 'missing', availability: 'not available' }] },
      { index: 11, name: 'hdmi', description: 'HDMI', volume: volume(), properties: { 'object.serial': '101' } }],
    sources: [{ index: 20, name: 'microphone', description: 'Microphone', volume: volume(), mute: true,
      monitor_of_sink: null, properties: { 'object.serial': '200' } },
      { index: 21, name: 'speakers.monitor', description: 'Speakers monitor', volume: volume(), monitor_of_sink: 'speakers' }],
    'sink-inputs': [{ index: 30, client: 5, sink: 10, volume: volume(), mute: false, corked: true,
      properties: { 'object.serial': '300', 'application.name': 'Teams', 'application.process.id': '500', 'media.name': 'Call playback' } }],
    'source-outputs': [{ index: 40, client: 5, source: 20, volume: volume(), mute: false,
      properties: { 'object.serial': '400', 'application.name': 'Teams', 'application.process.id': '500', 'media.name': 'Call microphone' } },
      { index: 41, properties: { 'application.name': 'Quickshell Peak Detect' }, volume: volume() }],
    cards: [{ index: 1, name: 'card', properties: { 'device.description': 'Built-in audio', 'object.serial': '1' },
      active_profile: 'stereo', profiles: [{ name: 'stereo', description: 'Stereo', available: 'yes' },
        { name: 'headset', description: 'Headset', available: 'unknown' }, { name: 'off', description: 'Off' },
        { name: 'missing', available: 'no' }] }],
  };
  const stateFile = path.join(root, 'state.json');
  const save = () => fs.writeFileSync(stateFile, JSON.stringify(state));
  save();
  fs.writeFileSync(path.join(root, 'pactl'), `#!/usr/bin/python3
import json, os, sys
from pathlib import Path
p = Path(os.environ['MIXER_STATE'])
data = json.loads(p.read_text())
args = sys.argv[1:]
if args[:3] == ['-f', 'json', 'list']:
  print(json.dumps(data[args[3]])); sys.exit(0)
with open(os.environ['MIXER_LOG'], 'a') as log: log.write(json.dumps(args) + '\\n')
if os.environ.get('IGNORE_MIXER_CHANGE'): sys.exit(0)
command = args[0]
kind = next(k for k in ['sink-input', 'source-output', 'sink', 'source', 'card'] if k in command)
plural = {'sink-input':'sink-inputs', 'source-output':'source-outputs', 'sink':'sinks', 'source':'sources', 'card':'cards'}[kind]
item = next(i for i in data[plural] if i['index'] == int(args[1]))
if command.endswith('-volume'):
  values = [float(v.rstrip('%')) for v in args[2:]]
  old = [v['value'] for v in item['volume'].values()]
  for n, v in enumerate(item['volume'].values()):
    v['value'] = round((values[n] if len(values) > 1 else values[0] * old[n] / max(old)) / 100 * 65536)
elif command.endswith('-mute'): item['mute'] = args[2] == '1'
elif command.startswith('move-'): item['sink' if kind == 'sink-input' else 'source'] = int(args[2])
elif command.endswith('-port'): item['active_port'] = args[2]
elif command.endswith('-profile'): item['active_profile'] = args[2]
p.write_text(json.dumps(data))
`, { mode: 0o755 });
  const env = { ...process.env, PATH: `${root}:/usr/bin:/bin`, MIXER_STATE: stateFile, MIXER_LOG: path.join(root, 'log') };
  const run = request => spawnSync('python3', [helper, ...(request ? [JSON.stringify(request)] : [])], { env, encoding: 'utf8' });
  const snapshot = () => { const result = run(); assert.equal(result.status, 0, result.stderr); return JSON.parse(result.stdout); };
  const change = (target, operation, value, extra = {}) => {
    const result = run({ kind: target.kind, token: target.token, operation, value, ...extra });
    assert.equal(result.status, 0, result.stderr);
    return JSON.parse(result.stdout);
  };
  const log = () => fs.existsSync(env.MIXER_LOG) ? fs.readFileSync(env.MIXER_LOG, 'utf8').trim().split('\n').map(JSON.parse) : [];
  return { state, save, run, snapshot, change, env, log };
}

test('snapshot includes paused playback, recording, channels, ports and card modes without peak streams', t => {
  const f = fixture(t);
  const data = f.snapshot();
  assert.equal(data.streams.length, 2);
  assert.equal(data.streams[0].paused, true);
  assert.equal(data.streams[0].appKey, data.streams[1].appKey);
  assert.equal(data.streams[0].volume, 50);
  assert.deepEqual(data.streams[0].channels.map(c => c.value), [50, 25]);
  assert.equal(data.devices.find(d => d.name === 'microphone').monitor, false);
  assert.match(data.devices.find(d => d.name.endsWith('.monitor')).description, /^System audio/);
  assert.equal(data.devices[0].ports.length, 2);
  assert.equal(data.cards[0].profiles.length, 3);
  assert.deepEqual(f.log(), [], 'snapshot never changes audio');
});

test('stream volume, channel and mute controls target captured streams and preserve linked balance', t => {
  const f = fixture(t);
  const target = f.snapshot().streams[0];
  let data = f.change(target, 'volume', 80);
  assert.deepEqual(data.streams[0].channels.map(c => c.value), [80, 40]);
  data = f.change(target, 'channel', 30, { channel: 'front-right' });
  assert.deepEqual(data.streams[0].channels.map(c => c.value), [80, 30]);
  data = f.change(target, 'mute', true);
  assert.equal(data.streams[0].muted, true);
  assert.equal(data.devices[0].muted, false);
});

test('recording mute does not mute the physical microphone and monitor routing is explicit', t => {
  const f = fixture(t);
  const data = f.snapshot();
  const recording = data.streams.find(s => s.kind === 'recording');
  const monitor = data.devices.find(d => d.monitor);
  const next = f.change(recording, 'route', null, { deviceToken: monitor.token });
  assert.equal(next.streams.find(s => s.kind === 'recording').deviceIndex, 21);
  f.change(recording, 'mute', true);
  assert.deepEqual(f.log().map(command => command[0]), ['move-source-output', 'set-source-output-mute']);
});

test('ports, profiles and non-default device volume use validated choices', t => {
  const f = fixture(t);
  const data = f.snapshot();
  assert.equal(f.change(data.devices[0], 'port', 'headphones').devices[0].activePort, 'headphones');
  assert.equal(f.change(data.cards[0], 'profile', 'headset').cards[0].activeProfile, 'headset');
  assert.equal(f.change(data.devices[1], 'volume', 125).devices[1].volume, 125);
  assert.equal(f.run({ kind: 'output', token: data.devices[0].token, operation: 'port', value: 'missing' }).status, 1);
  assert.equal(f.run({ kind: 'card', token: data.cards[0].token, operation: 'profile', value: 'missing' }).status, 1);
});

test('stale indices, replaced route targets and invalid values fail before issuing commands', t => {
  const f = fixture(t);
  const data = f.snapshot();
  f.state['sink-inputs'][0].properties['object.serial'] = 'replacement';
  f.save();
  assert.equal(f.run({ ...data.streams[0], operation: 'mute', value: true }).status, 1);
  const current = f.snapshot().streams[0];
  f.state.sinks[1].properties['object.serial'] = 'replacement-device';
  f.save();
  assert.equal(f.run({ ...current, operation: 'route', deviceToken: data.devices[1].token }).status, 1);
  for (const value of [-1, 151, '50', true])
    assert.equal(f.run({ ...current, operation: 'volume', value }).status, 1);
  assert.deepEqual(f.log(), []);
});

test('command success without confirmed state is reported as failure', t => {
  const f = fixture(t);
  f.env.IGNORE_MIXER_CHANGE = '1';
  const result = f.run({ ...f.snapshot().streams[0], operation: 'volume', value: 80 });
  assert.equal(result.status, 1);
  assert.match(result.stderr, /Could not confirm/);
});

test('legacy dictionary profiles and object-valued active profiles normalize correctly', t => {
  const f = fixture(t);
  f.state.cards[0].profiles = { stereo: { description: 'Stereo', available: 'yes' }, off: { description: 'Off' } };
  f.state.cards[0].active_profile = { name: 'stereo' };
  f.save();
  assert.equal(f.snapshot().cards[0].activeProfile, 'stereo');
  assert.equal(f.change(f.snapshot().cards[0], 'profile', 'off').cards[0].activeProfile, 'off');
});

function extract(name, context) {
  const match = source.match(new RegExp(`^( +)function ${name}\\([^]*?\\n\\1\\}`, 'm'));
  assert.ok(match, name);
  return vm.runInNewContext(`(${match[0]})`, context);
}

test('slider queue coalesces by captured object and channel, without losing independent controls', () => {
  let restarts = 0;
  const mixer = { queue: [] };
  const change = extract('change', { mixer, dispatch: { restart: () => restarts++ } });
  change({ kind: 'playback', token: 'a' }, 'volume', 20);
  change({ kind: 'playback', token: 'a' }, 'volume', 30);
  change({ kind: 'recording', token: 'b' }, 'mute', true);
  change({ kind: 'output', token: 'c' }, 'channel', 40, { channel: 'front-left' });
  change({ kind: 'output', token: 'c' }, 'channel', 50, { channel: 'front-right' });
  assert.equal(mixer.queue.length, 4);
  assert.equal(mixer.queue[0].request.value, 30);
  assert.equal(restarts, 5);
});

test('keyed mixer rows retain order and update payloads without recreating surviving delegates', () => {
  const rows = [{ identity: 'b', payload: '{}' }, { identity: 'a', payload: '{}' }];
  const model = { get count() { return rows.length; }, get: i => rows[i], remove: i => rows.splice(i, 1),
    setProperty: (i, key, value) => { rows[i][key] = value; }, append: item => rows.push(item) };
  const survivor = rows[0];
  extract('syncModel', {})(model, [{ key: 'a', name: 'A' }, { key: 'b', name: 'B' }, { key: 'c', name: 'C' }]);
  assert.deepEqual(rows.map(r => r.identity), ['b', 'a', 'c']);
  assert.equal(rows[0], survivor);
  assert.equal(JSON.parse(rows[0].payload).name, 'B');
});

test('nuanced mixer controls run only in System Settings Audio, not the bar popup', () => {
  const settings = fs.readFileSync(path.resolve(__dirname, '../SystemSettings.qml'), 'utf8');
  const service = fs.readFileSync(path.resolve(__dirname, '../AudioService.qml'), 'utf8');
  const popup = fs.readFileSync(path.resolve(__dirname, '../AudioOutputCenter.qml'), 'utf8');
  assert.match(settings, /property: "mixerSettingsActive"\s+value: window.visible && window.section === "audio"/);
  assert.match(service, /AudioMixer \{ active: service.mixerSettingsActive \}/);
  assert.match(settings, /SoundMixerControls \{[^]*?visible: window.section === "audio"/);
  assert.match(settings, /command: \["pavucontrol"\]/);
  assert.doesNotMatch(popup, /SoundMixerControls|pavucontrol/);
  assert.match(popup, /openSystemSettings\(popup.panel.screen, "audio"\)/);
});
