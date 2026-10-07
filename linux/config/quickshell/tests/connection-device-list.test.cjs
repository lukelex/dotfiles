const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');
const source = fs.readFileSync(path.join(__dirname, '../ConnectionDeviceList.qml'), 'utf8');

function setup(keys) {
  const model = [];
  const nodes = new Map();
  let focus = '';
  const view = { entries: keys.map(key => ({ key })), keyForEntry: entry => entry.key,
    panelVisible: true, keyboardEnabled: true, interacting: false, moving: false,
    contentY: 0, height: 100, readingAnchor: null, pendingFocusKey: '', reconciling: false,
    focusFallback: { forceActiveFocus() { focus = 'fallback'; } } };
  Object.defineProperties(view, {
    focusedKey: { get: () => focus },
    contentHeight: { get: () => model.length * 50 },
  });
  const records = {
    get count() { return model.length; }, get(index) { return model[index]; },
    insert(index, row) {
      model.splice(index, 0, row);
      nodes.set(row.deviceKey, { height: 50, forceActiveFocus() { focus = row.deviceKey; } });
    },
    move(from, to) { model.splice(to, 0, model.splice(from, 1)[0]); },
    remove(index, count) { model.splice(index, count); },
    setProperty(index, key, value) { model[index][key] = value; },
  };
  const items = { get count() { return model.length; }, itemAt(index) { return nodes.get(model[index]?.deviceKey); } };
  const rows = { forceLayout() { model.forEach((row, index) => { nodes.get(row.deviceKey).y = index * 50; }); } };
  const listHover = { hovered: false, point: { position: { y: 0 } } };
  const context = vm.createContext({ view, records, items, rows, listHover, Qt: { callLater() {} } });
  for (const name of ['sync', 'restore']) {
    const match = source.match(new RegExp(`^  function ${name}\\([^]*?\\n  \\}`, 'm'));
    view[name] = vm.runInContext(`(${match[0]})`, context);
  }
  view.sync();
  return { view, model, nodes, listHover, focus: key => { focus = key; }, getFocus: () => focus };
}

test('surviving rows preserve delegates and viewport position across removal', () => {
  const { view, nodes } = setup(['a', 'b', 'c', 'd', 'e']);
  const node = nodes.get('c');
  view.contentY = 110;
  view.entries = view.entries.filter(entry => entry.key !== 'a');
  view.sync();
  assert.equal(nodes.get('c'), node);
  assert.equal(view.contentY, 60);
});

test('updates defer sorting while interacting and append arrivals without moving existing targets', () => {
  const { view, model, listHover } = setup(['a', 'b', 'c']);
  view.interacting = true;
  listHover.hovered = true;
  view.entries = [{ key: 'c' }, { key: 'd' }, { key: 'a' }, { key: 'b' }];
  view.sync();
  assert.deepEqual(model.map(row => row.deviceKey), ['a', 'b', 'c', 'd']);
  view.interacting = false;
  listHover.hovered = false;
  view.sync();
  assert.deepEqual(model.map(row => row.deviceKey), ['c', 'd', 'a', 'b']);
});

test('removing focused row focuses its surviving neighbor, then falls back when empty', () => {
  const { view, focus, getFocus } = setup(['a', 'b', 'c']);
  focus('b');
  view.entries = view.entries.filter(entry => entry.key !== 'b');
  view.sync();
  assert.equal(getFocus(), 'c');
  view.entries = [];
  view.sync();
  assert.equal(getFocus(), 'fallback');
});

test('manual scrolling suppresses compensation and shortened content clamps at bottom', () => {
  const { view } = setup(['a', 'b', 'c', 'd']);
  view.contentY = 90;
  view.moving = true;
  view.entries = view.entries.slice(1);
  view.sync();
  assert.equal(view.contentY, 90);
  view.moving = false;
  view.contentY = 50;
  view.entries = view.entries.slice(1);
  view.sync();
  assert.equal(view.contentY, 0);
});
