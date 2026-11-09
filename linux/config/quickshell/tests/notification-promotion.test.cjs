const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');

const source = fs.readFileSync(path.join(__dirname, '../NotificationCenter.qml'), 'utf8');

function fixture() {
  const later = [];
  const animation = () => ({ running: false, stop() { this.running = false; }, start() { this.running = true; } });
  const context = vm.createContext({
    popup: { pinned: false, closePending: false, promotionPending: false, promotionSnapshot: null, pinRequest: 0 },
    preview: { visible: false, contentItem: { Window: { window: { raise() {} } } } },
    pinnedPopup: { visible: false },
    content: { opacity: 1, y: 0, nativeWindow: {}, forceActiveFocus() { this.focused = true; },
      grabToImage(callback) {
        later.push(() => {
          callback({ url: 'image://test/snapshot' });
          if (context.popup.promotionSnapshot)
            context.Qt.callLater(context.popup.openPinned, context.popup.pinRequest);
        });
        return true;
      },
    },
    openAnim: animation(), closeAnim: animation(),
    headerMenu: { close() {}, open() {} },
    hoverCloseTimer: { stop() {}, restart() { assert.fail('Pinned panel must not hover-close'); } },
    Qt: { callLater(callback, ...args) { later.push(() => callback(...args)); } },
  });
  Object.defineProperty(context.popup, 'visible', { get: () => context.preview.visible || context.pinnedPopup.visible });
  for (const match of source.matchAll(/^  function (\w+)\(([^\n]*)\) \{\n([\s\S]*?)^  \}/gm))
    context.popup[match[1]] = vm.runInContext(`(function(${match[2]}) {${match[3]}\n})`, context);
  for (const name of ['open', 'close']) {
    const match = source.match(new RegExp(`^    function ${name}\\(\\) \\{\\n([\\s\\S]*?)^    \\}`, 'm'));
    context.pinnedPopup[name] = vm.runInContext(`(function() {${match[1]}\n})`, context);
  }
  const frame = source.match(/^    function onFrameSwapped\(\) \{\n([\s\S]*?)^    \}/m);
  return { ...context, frame: vm.runInContext(`(function() {${frame[1]}\n})`, context),
    flush() { while (later.length) later.shift()(); } };
}

test('promotion retains the preview snapshot until a pinned frame and focuses content', () => {
  const f = fixture();
  f.popup.requestOpen();
  f.content.opacity = 1;
  f.openAnim.running = false;
  f.popup.requestOpen(true);
  f.flush();
  assert.equal(f.preview.visible, true);
  assert.equal(f.pinnedPopup.visible, true);
  assert.equal(f.content.focused, true);
  assert.equal(f.openAnim.running, false);
  f.popup.requestHoverClose();
  f.frame();
  assert.equal(f.preview.visible, false);
  assert.equal(f.popup.promotionSnapshot, null);
  f.popup.requestClose(true);
  assert.equal(f.popup.visible, false);
  assert.equal(f.popup.pinned, false);
});

test('closing invalidates both deferred opens and in-flight snapshots', () => {
  for (const preview of [false, true]) {
    const f = fixture();
    if (preview) f.popup.requestOpen();
    f.popup.requestOpen(true);
    f.popup.requestClose(true);
    f.flush();
    assert.equal(f.popup.visible, false);
    assert.equal(f.popup.promotionSnapshot, null);
    f.popup.requestOpen();
    assert.equal(f.preview.visible, true);
    assert.equal(f.pinnedPopup.visible, false);
  }
});

test('failed snapshot leaves preview available for retry', () => {
  const f = fixture();
  f.popup.requestOpen();
  f.content.grabToImage = () => false;
  f.popup.requestOpen(true);
  assert.equal(f.popup.pinned, false);
  assert.equal(f.popup.promotionPending, false);
  assert.equal(f.preview.visible, true);
});
