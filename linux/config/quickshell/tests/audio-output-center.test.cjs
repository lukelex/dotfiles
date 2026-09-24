const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');

const source = fs.readFileSync(path.join(__dirname, '..', 'AudioOutputCenter.qml'), 'utf8');

function loadFunction(name, globals) {
  const match = source.match(new RegExp(`  function ${name}\\([^]*?\\n  \\}`));
  assert.ok(match, `Missing AudioOutputCenter function ${name}`);
  return vm.runInNewContext(`(${match[0]})`, globals);
}

test('hover opening refreshes devices and shows the preview without pinning', () => {
  const popup = {
    visible: false,
    pinned: false,
    closing: false,
    promotionPending: false,
    pinRequest: 0,
    service: { refresh(force) { this.forced = force; } },
    cancelClose() {},
  };
  const preview = { visible: false };
  const content = { opacity: 0 };
  let opened = false;
  loadFunction('requestOpen', {
    popup,
    preview,
    content,
    closeAnim: { stop() {} },
    openAnim: { running: false, start() { opened = true; } },
    pinnedPopup: { visible: false },
    Qt: { callLater() {} },
  })();

  assert.equal(popup.service.forced, true);
  assert.equal(preview.visible, true);
  assert.equal(popup.pinned, false);
  assert.equal(opened, true);
});

test('selecting an output pins the widget before applying the device', () => {
  const calls = [];
  const popup = {
    requestOpen(pin) { calls.push(['open', pin]); },
    service: { setDefaultSink(name) { calls.push(['select', name]); } },
  };
  const outputRow = { enabled: true, device: { name: 'sink-usb' } };
  const match = source.match(/    function activate\(\) \{[^]*?\n    \}/);
  assert.ok(match, 'Missing OutputDeviceRow.activate');
  vm.runInNewContext(`(${match[0]})`, { popup, outputRow })();
  assert.deepEqual(calls, [['open', true], ['select', 'sink-usb']]);
});

test('leaving the preview schedules closure only while it is not pinned', () => {
  let scheduled = 0;
  const popup = { pinned: false };
  const scheduleClose = loadFunction('scheduleClose', {
    popup,
    closeTimer: { restart() { scheduled++; } },
  });

  scheduleClose();
  assert.equal(scheduled, 1);
  popup.pinned = true;
  scheduleClose();
  assert.equal(scheduled, 1);
});
