const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');

const source = fs.readFileSync(path.join(__dirname, '../NotificationCenter.qml'), 'utf8');

function fixture() {
  const service = { activationPendingId: null, activationErrorId: null, activationError: '', history: [{ id: 'target' }] };
  const popup = { service, expandedGroupKey: 'group', pinRequest: 0, activationReturn: null,
    readingEntries: () => [{ id: 'target', y: 150 }],
    requestOpen(pin) { this.opened = pin; } };
  const context = { popup, historyView: { contentY: 120 },
    headerMenu: { close() {} }, hoverCloseTimer: { stop() {} },
    openAnim: { stop() {} }, closeAnim: { stop() {} },
    preview: { visible: true }, pinnedPopup: { visible: false } };
  for (const name of ['activateFromCenter', 'checkActivationReturn', 'requestClose']) {
    const match = source.match(new RegExp(`  function ${name}\\([^]*?\\n  \\}`));
    popup[name] = vm.runInNewContext(`(${match[0]})`, context);
  }
  return { popup, service, context };
}

test('synchronous opening failure releases the grab first and restores the target position', () => {
  const { popup, service, context } = fixture();
  service.activateRecord = id => {
    assert.equal(context.preview.visible, false);
    service.activationErrorId = id;
    service.activationError = 'Unavailable';
    return false;
  };
  popup.activateFromCenter('target');
  assert.equal(popup.opened, true);
  assert.equal(popup.restoreAfterOpen.id, 'target');
  assert.equal(popup.restoreAfterOpen.contentY, 120);
  assert.equal(popup.restoreAfterOpen.expandedGroupKey, 'group');
  assert.equal(popup.restoreAfterOpen.offset, 30);
});

test('asynchronous failure reopens only the originating, uncancelled attempt', () => {
  for (const cancel of [false, true]) {
    const { popup, service } = fixture();
    service.activateRecord = id => { service.activationPendingId = id; return true; };
    popup.activateFromCenter('target');
    assert.equal(popup.opened, undefined);
    if (cancel) popup.requestClose(true);
    service.activationPendingId = null;
    service.activationErrorId = 'target';
    service.activationError = 'Failed';
    popup.checkActivationReturn();
    assert.equal(popup.opened, cancel ? undefined : true);
  }
});

test('success, removed records and unrelated errors never reopen history', () => {
  for (const outcome of ['success', 'removed', 'unrelated']) {
    const { popup, service } = fixture();
    service.activateRecord = id => {
      if (outcome === 'removed') service.history = [];
      service.activationErrorId = outcome === 'unrelated' ? 'other' : id;
      service.activationError = outcome === 'success' ? '' : 'Failed';
    };
    popup.activateFromCenter('target');
    assert.equal(popup.opened, undefined);
    assert.equal(popup.activationReturn, null);
  }
});

test('synthetic negative action indexes remain actions and competing requests are ignored', () => {
  const { popup, service } = fixture();
  let calls = 0;
  service.invokeAction = (id, index) => { assert.equal(id, 'target'); assert.equal(index, -1); calls++; };
  popup.activateFromCenter('target', -1);
  service.activationPendingId = 'other';
  popup.activateFromCenter('target', -1);
  assert.equal(calls, 1);
});
