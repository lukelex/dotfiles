const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');

const source = fs.readFileSync(path.join(__dirname, '../ConnectivityCenter.qml'), 'utf8');

function fixture() {
  const later = [];
  const animation = () => ({ running: false, stop() { this.running = false; }, start() { this.running = true; } });
  const context = vm.createContext({
    popup: { pinned: false, closing: false, closeImmediately: false, promotionPending: false, promotionSnapshot: null, promotionWindow: null, pinRequest: 0 },
    preview: { visible: false, contentItem: { Window: { window: { raise() {} } } } },
    pinnedPopup: { visible: false, open() { this.visible = true; context.onOpened(); }, close() { this.visible = false; } },
    content: {
      opacity: 1, y: 0, forceActiveFocus() {}, nativeWindow: {},
      grabToImage(callback) {
        later.push(() => {
          callback({ url: 'image://test/snapshot' });
          if (context.popup.promotionSnapshot)
            context.Qt.callLater(context.popup.openPinned, context.popup.pinRequest);
        });
        return true;
      },
    },
    sections: { implicitHeight: 200 },
    openAnim: animation(), closeAnim: animation(), closeTimer: { stop() {}, restart() {} },
    Qt: { callLater(callback, ...args) { later.push(() => callback(...args)); } },
  });
  Object.defineProperty(context.popup, 'visible', { get: () => context.preview.visible || context.pinnedPopup.visible });
  for (const match of source.matchAll(/^  function (\w+)\(([^\n]*)\) \{\n([\s\S]*?)^  \}/gm)) {
    context.popup[match[1]] = vm.runInContext(`(function(${match[2]}) {\n${match[3]}\n})`, context);
  }
  const opened = source.match(/^    onOpened: \{\n([\s\S]*?)^    \}/m);
  assert.ok(opened, 'Missing pinned popup open handler');
  context.onOpened = vm.runInContext(`(function() {\n${opened[1]}\n})`, context);
  const frame = source.match(/^    function onFrameSwapped\(\) \{\n([\s\S]*?)^    \}/m);
  assert.ok(frame, 'Missing native frame-ready handler');
  const frameSwapped = vm.runInContext(`(function() {\n${frame[1]}\n})`, context);
  return { ...context, frameSwapped, flush() { while (later.length) later.shift()(); } };
}

test('clicking a control keeps the preview visible and does not replay its entrance', () => {
  const f = fixture();
  f.popup.requestOpen();
  f.content.opacity = 1;
  f.content.y = 0;
  f.openAnim.running = false;
  f.popup.requestOpen(true);
  assert.equal(f.preview.visible, true);
  assert.equal(f.popup.visible, true);
  assert.equal(f.pinnedPopup.visible, false);
  f.flush();
  assert.equal(f.preview.visible, true, 'Preview remains during snapshot bridge');
  assert.equal(f.pinnedPopup.visible, true);
  assert.ok(f.popup.promotionSnapshot);
  assert.equal(f.popup.promotionWindow, f.content.nativeWindow);
  assert.equal(f.content.opacity, 1);
  assert.equal(f.content.y, 0);
  assert.equal(f.openAnim.running, false);
  f.frameSwapped();
  assert.equal(f.preview.visible, false);
  assert.equal(f.popup.promotionSnapshot, null);
  assert.equal(f.popup.promotionWindow, null);
});

test('closing before a snapshot completes cannot pin a later hover session', () => {
  const f = fixture();
  f.popup.requestOpen();
  f.popup.requestOpen(true);
  f.popup.requestClose(true);
  f.popup.requestOpen();
  f.flush();
  assert.equal(f.preview.visible, true);
  assert.equal(f.pinnedPopup.visible, false);
  assert.equal(f.popup.promotionSnapshot, null);
});

test('a failed snapshot leaves the preview usable and allows a later retry', () => {
  const f = fixture();
  f.popup.requestOpen();
  f.content.grabToImage = () => false;
  f.popup.requestOpen(true);
  assert.equal(f.preview.visible, true);
  assert.equal(f.popup.pinned, false);
  assert.equal(f.popup.promotionPending, false);
});

test('closing a deferred pin prevents the queued native open', () => {
  const f = fixture();
  f.popup.requestOpen(true);
  f.popup.requestClose(true);
  f.flush();
  assert.equal(f.popup.visible, false);
});

test('an obsolete queued open cannot promote a newer session', () => {
  const f = fixture();
  f.popup.requestOpen(true);
  const oldRequest = f.popup.pinRequest;
  f.popup.requestClose(true);
  f.popup.requestOpen(true);
  f.popup.openPinned(oldRequest);
  assert.equal(f.pinnedPopup.visible, false);
  f.flush();
  assert.equal(f.pinnedPopup.visible, true);
});
