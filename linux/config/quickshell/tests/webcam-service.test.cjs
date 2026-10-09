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
  assert.match(source, /objects: service\.cameraNodes\.concat\(service\.cameraLinks\)/);
  assert.match(bar, /visible: root\.webcamService\.inUse\n\s+source: root\.icon\("webcam"\)\n\s+color: root\.controlActiveIcon/);
  assert.ok(fs.existsSync(path.join(__dirname, '../../lucide/svg/webcam.svg')));
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
  (sysfs / 'video0' / 'index').unlink()
  assert not scan(sysfs, proc)
  (sysfs / 'video0' / 'index').write_text('0')
  descriptor.unlink()
  fd.rmdir()
  assert not scan(sysfs, proc)
`], { encoding: 'utf8', timeout: 5000 });
  assert.equal(result.status, 0, result.stderr);
});
