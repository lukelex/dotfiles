const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { spawnSync } = require('node:child_process');
const { test } = require('node:test');

const source = fs.readFileSync(path.join(__dirname, '../WebcamService.qml'), 'utf8');
const bar = fs.readFileSync(path.join(__dirname, '../Bar.qml'), 'utf8');
const isCamera = vm.runInNewContext(`(${source.match(/  function isCamera\([^]*?\n  \}/)[0]})`, {
  PwNodeType: { VideoSource: 1 },
});

test('camera detection excludes screen sharing, audio and unclassified video sources', () => {
  for (const properties of [{ 'device.api': 'v4l2' }, { 'device.api': 'libcamera' },
    { 'api.v4l2.path': '/dev/video0' }, { 'api.libcamera.path': '/camera' }]) {
    assert.equal(isCamera({ type: 1, properties }), true);
    assert.equal(isCamera({ type: 2, properties }), false);
  }
  assert.equal(isCamera({ type: 1, properties: { 'media.name': 'Screen cast' } }), false);
  assert.equal(isCamera({ type: 1 }), false);
});

test('only active camera links or direct device access show the shared bar indicator', () => {
  const expression = source.match(/readonly property bool inUse: (.*)/)[1];
  const evaluate = (links, directInUse = false) => vm.runInNewContext(expression, {
    directInUse, cameraLinks: links, PwLinkState: { Active: 1 },
  });
  assert.equal(evaluate([]), false);
  assert.equal(evaluate([{ state: 0 }]), false);
  assert.equal(evaluate([{ state: 1 }]), true);
  assert.equal(evaluate([], true), true);
  assert.match(source, /objects: service\.cameraNodes\.concat\(service\.cameraLinks, service\.cameraLinks\.map\(group => group\.target\)\)/);
  assert.match(bar, /visible: root\.webcamService\.inUse\n\s+source: root\.icon\("webcam"\)\n\s+color: root\.controlActiveIcon/);
  assert.ok(fs.existsSync(path.join(__dirname, '../../lucide/svg/webcam.svg')));
});

test('webcam hints collect active app names from PipeWire and direct access', () => {
  const collect = vm.runInNewContext(`(${source.match(/  function collectRecordingApplications\([^]*?\n  \}/)[0]})`, {
    service: { isCamera }, PwLinkState: { Active: 1 },
  });
  const link = (state, properties, type = 1, description = '') => ({
    state, source: { type, properties: { 'device.api': 'v4l2' } },
    target: { properties, description },
  });
  assert.deepEqual(Array.from(collect([
    link(1, { 'application.name': 'Firefox' }),
    link(1, { 'application.name': 'Firefox' }),
    link(1, { 'application.process.binary': 'zoom' }),
    link(0, { 'application.name': 'Inactive' }),
    link(1, { 'application.name': 'Screen sharing' }, 2),
    link(1, {}, 1, 'Camera app'),
    link(1, {}),
  ], ['Firefox', 'chromium'])), ['Camera app', 'Firefox', 'Unknown application', 'chromium', 'zoom'].sort((a, b) => a.localeCompare(b)));
});

test('both privacy icons show app hints and microphone clicks retain the sound picker', () => {
  const widgets = bar.slice(bar.indexOf('id: rightWidgets'), bar.indexOf('source: root.icon("message-square-quote")'));
  assert.match(widgets, /trigger: microphoneHover/);
  assert.match(widgets, /recordingApplications\.map\(application => application\.name\)/);
  assert.match(widgets, /trigger: webcamHover/);
  assert.match(widgets, /applications: root\.webcamService\.recordingApplications/);
  assert.match(widgets, /onClicked: panel\.openAudioOutput\(true\)/);
  assert.doesNotMatch(widgets, /onEntered: panel\.openAudioOutput/);
});

test('webcam details associate actual cameras with each app and deduplicate links', () => {
  const collect = vm.runInNewContext(`(${source.match(/  function collectApplicationDevices\([^]*?\n  \}/)[0]})`, {
    service: { isCamera }, PwLinkState: { Active: 1 },
  });
  const link = (name, device, description, state = 1) => ({
    state,
    source: { type: 1, description, properties: { 'device.api': 'v4l2', 'api.v4l2.path': device } },
    target: { properties: { 'application.name': name } },
  });
  const links = [link('Firefox', '/dev/video0', 'Desk camera'),
    link('Firefox', '/dev/video0', 'Desk camera'),
    link('Firefox', '/dev/video2', 'Laptop camera'),
    link('Zoom', '/dev/video2', 'Laptop camera'),
    link('Idle', '/dev/video4', 'Unused camera', 0)];
  const details = collect(links, [{ name: 'Firefox', devicePath: '/dev/video0', deviceName: 'Desk camera' }]);
  assert.equal(details.Firefox, 'Desk camera · /dev/video0\nLaptop camera · /dev/video2');
  assert.equal(details.Zoom, 'Laptop camera · /dev/video2');
  assert.equal(details.Idle, undefined);
  assert.equal(collect([link('Unknown', '', '')], []).Unknown, 'Unknown webcam');
});

test('microphone and webcam activity indicators lead the right-hand icon list', () => {
  const widgets = bar.slice(bar.indexOf('id: rightWidgets'));
  const microphone = widgets.indexOf('visible: root.audioService.microphoneInUse');
  const webcam = widgets.indexOf('visible: root.webcamService.inUse');
  const reviews = widgets.indexOf('source: root.icon("message-square-quote")');
  assert.ok(microphone > 0 && webcam > microphone && reviews > webcam);
  assert.equal((widgets.match(/visible: root.audioService.microphoneInUse/g) || []).length, 1);
  assert.equal((widgets.match(/visible: root.webcamService.inUse/g) || []).length, 1);
});

test('direct access scanner handles idle, capture, metadata, unplug and process exit without opening devices', () => {
  const script = path.resolve(__dirname, '../scripts/webcam-status.py');
  const result = spawnSync('python3', ['-B', '-c', `
import runpy
import tempfile
from pathlib import Path
scan = runpy.run_path(${JSON.stringify(script)})['in_use']
apps = runpy.run_path(${JSON.stringify(script)})['applications']
usage = runpy.run_path(${JSON.stringify(script)})['usage']
with tempfile.TemporaryDirectory(prefix='webcam-test-', dir='/tmp/opencode') as root:
  root = Path(root)
  sysfs, proc = root / 'sys', root / 'proc'
  sysfs.mkdir()
  proc.mkdir()
  assert not scan(sysfs, proc)
  for number in range(2):
    node = sysfs / ('video' + str(number))
    node.mkdir()
    (node / 'index').write_text(str(number))
  fd = proc / '123' / 'fd'
  fd.mkdir(parents=True)
  descriptor = fd / '1'
  descriptor.symlink_to('/dev/video1')
  assert not scan(sysfs, proc)
  descriptor.unlink()
  descriptor.symlink_to('/dev/video0')
  assert scan(sysfs, proc)
  assert apps(sysfs, proc) == ['Unknown application']
  (proc / '123' / 'comm').write_text('fallback\\n')
  assert apps(sysfs, proc) == ['fallback']
  (proc / '123' / 'cmdline').write_bytes(b'/usr/bin/firefox\\0--camera\\0')
  assert apps(sysfs, proc) == ['firefox']
  (proc / '123' / 'cmdline').write_bytes(b'msedge --type=utility --camera\\0')
  assert apps(sysfs, proc) == ['msedge']
  (proc / '123' / 'exe').symlink_to('/usr/bin/firefox')
  assert apps(sysfs, proc) == ['firefox']
  (fd / '2').symlink_to('/dev/video0')
  other = proc / '456'
  (other / 'fd').mkdir(parents=True)
  (other / 'comm').write_text('zoom')
  (other / 'fd' / '1').symlink_to('/dev/video0')
  assert apps(sysfs, proc) == ['firefox', 'zoom']
  (sysfs / 'video0' / 'name').write_text('Desk camera')
  assert usage(sysfs, proc) == [
    {'name': 'firefox', 'devicePath': '/dev/video0', 'deviceName': 'Desk camera'},
    {'name': 'zoom', 'devicePath': '/dev/video0', 'deviceName': 'Desk camera'}]
  (sysfs / 'video2').mkdir()
  (sysfs / 'video2' / 'index').write_text('0')
  (fd / '3').symlink_to('/dev/video2')
  assert usage(sysfs, proc)[1] == {'name': 'firefox', 'devicePath': '/dev/video2', 'deviceName': '/dev/video2'}
  (fd / '3').unlink()
  (other / 'fd' / '1').unlink()
  (fd / '2').unlink()
  (sysfs / 'video0' / 'index').unlink()
  assert not scan(sysfs, proc)
  (sysfs / 'video0' / 'index').write_text('0')
  descriptor.unlink()
  fd.rmdir()
  assert not scan(sysfs, proc)
`], { encoding: 'utf8', timeout: 5000 });
  assert.equal(result.status, 0, result.stderr);
});
