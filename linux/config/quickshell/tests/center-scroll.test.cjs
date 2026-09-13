const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');

const source = fs.readFileSync(path.join(__dirname, '../NotificationCenter.qml'), 'utf8');

function loadFunction(name, globals = {}) {
  const match = source.match(new RegExp(`  function ${name}\\([^]*?\\n  \\}`));
  assert.ok(match, `Missing QML function ${name}`);
  return vm.runInNewContext(`(${match[0]})`, globals);
}

test('model reconciliation preserves surviving rows on removal and arrival', () => {
  const rows = [1, 2, 3].map(id => ({ notification: { id } }));
  const first = rows[0];
  const last = rows[2];
  const model = {
    get count() { return rows.length; },
    get: index => rows[index],
    insert: (index, value) => rows.splice(index, 0, value),
    remove: (index, count) => rows.splice(index, count),
    move: (from, to, count) => rows.splice(to, 0, ...rows.splice(from, count)),
    setProperty: (index, role, value) => { rows[index][role] = value; },
  };
  const reconcile = loadFunction('reconcileModel');
  reconcile(model, [{ id: 1 }, { id: 3 }], 'notification', 'id');
  assert.equal(rows[0], first);
  assert.equal(rows[1], last);
  reconcile(model, [{ id: 4 }, { id: 1 }, { id: 3 }], 'notification', 'id');
  assert.equal(rows[1], first);
  assert.equal(rows[2], last);
  assert.deepEqual(rows.map(row => row.notification.id), [4, 1, 3]);
});

test('surviving notification keeps its viewport offset after a removal', () => {
  const historyView = { contentY: 450, contentHeight: 1000, height: 400 };
  const popup = {
    readingAnchor: { id: 2, offset: 84 },
    readingEntries: () => [{ id: 2, y: 445 }],
  };
  loadFunction('restoreReadingPosition', { popup, historyView })();
  assert.equal(historyView.contentY, 361);
  assert.equal(445 - historyView.contentY, 84);
});

test('scroll clamps at the shortened bottom and respects user scrolling', () => {
  const historyView = { contentY: 450, contentHeight: 700, height: 400 };
  const popup = {
    readingAnchor: { id: 2, offset: 84 },
    readingEntries: () => [{ id: 2, y: 600 }],
  };
  const restore = loadFunction('restoreReadingPosition', { popup, historyView });
  restore();
  assert.equal(historyView.contentY, 300);
  historyView.contentHeight = 200;
  restore();
  assert.equal(historyView.contentY, 0);
  popup.readingAnchor = null;
  historyView.contentY = 50;
  restore();
  assert.equal(historyView.contentY, 50);
});
