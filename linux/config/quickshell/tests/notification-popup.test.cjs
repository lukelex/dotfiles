const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');

const source = fs.readFileSync(path.join(__dirname, '../NotificationPopup.qml'), 'utf8');

function load(name, globals, indent = 4) {
  const spaces = ' '.repeat(indent);
  const match = source.match(new RegExp(`${spaces}function ${name}\\([^]*?\\n${spaces}\\}`));
  assert.ok(match, `Missing ${name}`);
  return vm.runInNewContext(`(${match[0]})`, globals);
}

function fixture(ids = ['old', 'middle', 'new'], expanded = true) {
  const pending = new Set();
  const dismissed = [];
  const removed = [];
  const records = ids.map((id, index) => ({ id, appName: 'A', urgency: 'normal', time: index, height: 64 + index * 20 }));
  const rows = records.slice().reverse().map(notification => ({ notification }));
  const cards = rows.map(row => ({
    get record() { return row.notification; },
    get height() { return this.record.height; },
    get y() { return expandedColumn.cardY(cards.indexOf(this), this.height); },
    reflowOffset: 0,
    moveFrom(previousY) { this.reflowOffset = previousY - this.y; },
  }));
  const recordModel = {
    get count() { return rows.length; },
    get: index => rows[index],
    remove(index) { rows.splice(index, 1); cards.splice(index, 1); },
    setProperty(index, role, value) { rows[index][role] = value; },
  };
  const stack = {
    records, expanded, expandedHeight: 0, reflowPositions: null,
    expiring: false, pendingStackExpiryIds: [], expiringStackRecordId: '',
    get layerCount() { return Math.min(this.records.length, 3) - 1; },
    get showingExpanded() { return this.expanded && this.records.length > 0; },
    removeHandler(item) { removed.push(item); },
    service: {
      appKey: record => record.appName,
      popupGroupWindow: 30, notificationGroupWindow: 300,
      dismissRecord(id) { dismissed.push(id); },
      setHovered() {},
    },
  };
  const expandedCards = { get count() { return cards.length; }, itemAt: index => cards[index] };
  const expandedColumn = {
    spacing: 8,
    get height() { return stack.expandedHeight; },
    get contentHeight() { return cards.reduce((sum, card) => sum + card.height, 0) + Math.max(0, cards.length - 1) * 8; },
  };
  const expiryAnimation = { start() { this.running = true; }, stop() { this.running = false; } };
  const stackedExpiryTimer = { restart() { this.running = true; }, stop() { this.running = false; } };
  const globals = {
    stack, recordModel, expandedCards, expandedColumn, expiryAnimation, stackedExpiryTimer,
    expiryTranslate: { x: 0 }, latestToast: { dismissing: false }, stackHover: { hovered: false },
    reflowTimer: { restart() {} }, Qt: { callLater(callback) { pending.add(callback); } },
  };
  expandedColumn.cardY = load('cardY', globals, 6);
  for (const name of ['removeRecords', 'finishReflow', 'updateRecord', 'dismissRecord', 'updateExpandedHeight', 'expireRecord', 'finishStackExpiry', 'canAddRecord'])
    stack[name] = load(name, globals);
  stack.updateExpandedHeight();
  return {
    stack, cards, rows, dismissed, removed, expiryAnimation, stackedExpiryTimer,
    flush() { const callbacks = [...pending]; pending.clear(); callbacks.forEach(callback => callback()); },
  };
}

test('replacement updates the existing delegate even when another application arrived afterward', () => {
  const f = fixture();
  const original = f.cards[1];
  const replacement = { ...original.record, summary: 'Updated', height: 150 };
  let appended = false;
  const popup = { popupStacks: { count: 2, itemAt: index => index === 0 ? f.stack : {
    updateRecord: () => false,
    canAddRecord: () => true,
    addRecord() { appended = true; },
  } } };
  const add = load('addPopupRecord', { popup, popupGroupModel: { append() { appended = true; } } }, 2);
  add(replacement);
  f.flush();
  assert.equal(appended, false);
  assert.equal(f.cards.length, 3);
  assert.equal(f.cards[1], original);
  assert.equal(original.record.summary, 'Updated');
  assert.equal(f.stack.expandedHeight, 334);
});

test('a replacement cancels pending whole-stack expiry without removing the stack', () => {
  const f = fixture(['only'], false);
  f.stack.expireRecord('only');
  assert.equal(f.expiryAnimation.running, true);
  f.stack.updateRecord({ ...f.stack.records[0], summary: 'Replacement' });
  assert.equal(f.expiryAnimation.running, false);
  assert.equal(f.stack.expiring, false);
  assert.equal(f.stack.opacity, 1);
  assert.equal(f.removed.length, 0);
});

test('replacement during a collapsed expiry burst preserves only the replaced record', () => {
  const f = fixture(undefined, false);
  f.stack.expireRecord('old');
  f.stack.expireRecord('middle');
  f.stack.updateRecord({ ...f.stack.records[0], summary: 'Keep' });
  f.stack.finishStackExpiry();
  assert.deepEqual(Array.from(f.stack.records, record => record.id), ['old', 'new']);
});

for (const id of ['old', 'middle', 'new']) {
  for (const method of ['dismissRecord', 'expireRecord']) {
    test(`${method}(${id}) preserves the visual positions of unequal-height survivors`, () => {
      const f = fixture();
      const before = new Map(f.cards.map(card => [card.record.id, card.y]));
      f.stack[method](id);
      f.flush();
      assert.equal(f.cards.length, 2);
      for (const card of f.cards)
        assert.equal(card.y + card.reflowOffset, before.get(card.record.id));
      assert.equal(f.stack.reflowing, true);
      assert.deepEqual(f.dismissed, method === 'dismissRecord' ? [id] : []);
    });
  }
}

test('burst expiry captures the original positions once and tolerates repeated removal events', () => {
  const f = fixture(['a', 'b', 'c', 'd']);
  const before = new Map(f.cards.map(card => [card.record.id, card.y]));
  f.stack.expireRecord('d');
  f.stack.expireRecord('b');
  assert.equal(f.stack.expireRecord('d'), false);
  f.flush();
  for (const card of f.cards)
    assert.equal(card.y + card.reflowOffset, before.get(card.record.id));
});

test('a second removal during reflow starts from the current visual positions', () => {
  const f = fixture(['a', 'b', 'c', 'd']);
  f.stack.expireRecord('d');
  f.flush();
  for (const card of f.cards) card.reflowOffset /= 2;
  const before = new Map(f.cards.map(card => [card.record.id, card.y + card.reflowOffset]));
  f.stack.expireRecord('c');
  f.flush();
  for (const card of f.cards)
    assert.equal(card.y + card.reflowOffset, before.get(card.record.id));
});

test('dismissal reconciles both screen models without a second local exit', () => {
  const first = fixture();
  const second = fixture();
  const observed = [];
  first.stack.service.dismissRecord = id => {
    observed.push(first.stack.expireRecord(id));
    observed.push(second.stack.expireRecord(id));
  };
  first.stack.dismissRecord('new');
  first.flush();
  second.flush();
  assert.deepEqual(observed, [false, true]);
  assert.deepEqual(first.cards.map(card => card.record.id), ['middle', 'old']);
  assert.deepEqual(second.cards.map(card => card.record.id), ['middle', 'old']);
});

test('activation keeps the toast and history for failure, pending work and success', () => {
  for (const result of [false, true]) {
    let activations = 0;
    const toast = { dismissing: false, record: { id: 'target' }, service: {
      activateRecord(id) { assert.equal(id, 'target'); activations++; return result; },
      dismissRecord() { assert.fail('Opening must not delete history'); },
    } };
    load('activate', { toast, dismissAnimation: { start() { assert.fail('Opening must not dismiss'); } } })();
    assert.equal(activations, 1);
    assert.equal(toast.dismissing, false);
  }
});

test('reusing a toast resets dismissal independently from its expansion fade', () => {
  const toast = { dismissing: true, dismissingRecordId: 'old', dismissalOpacity: 0, presentationOpacity: 0.4 };
  const dismissTranslate = { x: 408 };
  let stopped = false;
  load('resetDismissal', { toast, dismissTranslate, dismissAnimation: { stop() { stopped = true; } } })();
  assert.equal(stopped, true);
  assert.equal(toast.dismissing, false);
  assert.equal(toast.dismissingRecordId, null);
  assert.equal(dismissTranslate.x, 0);
  assert.equal(toast.dismissalOpacity, 1);
  assert.equal(toast.presentationOpacity, 0.4);
});
