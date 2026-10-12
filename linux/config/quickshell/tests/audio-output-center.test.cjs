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

test('default device selectors pin before interaction and route through the existing audio service', () => {
  assert.match(source, /choices: popup.service.outputs[^]*?onInteracted: popup.requestOpen\(true\)[^]*?onChosen: option => popup.service.setDefaultSink\(option.name\)/);
  assert.match(source, /choices: popup.service.inputs[^]*?onInteracted: popup.requestOpen\(true\)[^]*?onChosen: option => popup.service.setDefaultSource\(option.name\)/);
  assert.match(source, /openSystemSettings\(popup.panel.screen, "audio"\)/);
  assert.doesNotMatch(source, /SoundMixerControls|pavucontrol/);
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
