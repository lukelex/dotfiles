const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');

const source = fs.readFileSync(path.join(__dirname, '../NotificationService.qml'), 'utf8');

function serviceForTest() {
  const service = { history: [], popup: [], live: {}, hovered: {}, popupLimit: 5, popupGroupWindow: 30 };
  const removed = [];
  service.popupRecordRemoved = id => removed.push(id);
  const context = vm.createContext({ service, Date });
  for (const name of ['appKey', 'groupHistory', 'groupPopup', 'computeExpiry', 'syncPopup', 'dismissRecords']) {
    const match = source.match(new RegExp(`  function ${name}\\([^]*?\\n  \\}`));
    assert.ok(match, `Missing QML function ${name}`);
    service[name] = vm.runInContext(`(${match[0]})`, context);
  }
  return { service, removed };
}

function record(id, appName = 'A', urgency = 'normal') {
  return { id, appName, urgency, time: id, expiresAt: Date.now() + 5000 };
}

test('only adjacent notifications with the same app and urgency group', () => {
  const { service } = serviceForTest();
  const records = [record(1), record(2), record(3, 'B'), record(4), record(5, 'A', 'critical'), record(6)];
  for (const group of [service.groupPopup, service.groupHistory]) {
    const ids = JSON.parse(JSON.stringify(group(records).map(entry => entry.records.map(item => item.id))));
    assert.deepEqual(ids, [[1, 2], [3], [4], [5], [6]]);
  }
});

test('timeouts use milliseconds and zero stays persistent', () => {
  const { service } = serviceForTest();
  const before = Date.now();
  const defaultExpiry = service.computeExpiry({ expireTimeout: -1 }, 'normal');
  assert.ok(defaultExpiry >= before + 10000 && defaultExpiry <= Date.now() + 10000);
  const expiry = service.computeExpiry({ expireTimeout: 1000 }, 'normal');
  assert.ok(expiry >= before + 1000 && expiry <= Date.now() + 1000);
  assert.equal(service.computeExpiry({ expireTimeout: 0 }, 'normal'), 0);
  assert.equal(service.computeExpiry({ expireTimeout: 1000 }, 'critical'), 0);
});

test('hover protects an overdue notification from a full burst', () => {
  const { service, removed } = serviceForTest();
  const reading = { ...record(1), expiresAt: Date.now() - 1000 };
  service.popup = [reading];
  service.history = [record(6), record(5), record(4), record(3), record(2), reading];
  for (const item of service.history) service.live[item.id] = {};
  service.hovered[1] = true;
  service.syncPopup();
  assert.equal(service.popup.length, 5);
  assert.ok(service.popup.some(item => item.id === 1));
  assert.deepEqual(removed, []);
  delete service.hovered[1];
  service.syncPopup();
  assert.deepEqual(removed, [1]);
});

test('already animated dismissal still reconciles service state', () => {
  const { service, removed } = serviceForTest();
  service.popup = [record(1)];
  service.syncPopup(1);
  assert.equal(service.popup.length, 0);
  assert.equal(service.popupReversed.length, 0);
  assert.deepEqual(removed, []);
});

test('clearing a snapshot preserves later arrivals and the OSD', () => {
  const { service } = serviceForTest();
  const original = record(1);
  const arrivedDuringAnimation = record(2);
  const dismissed = [];
  service.saveHistory = () => {};
  service.tagMap = {};
  service.osd = { id: 3, summary: 'Volume' };
  service.history = [arrivedDuringAnimation, original];
  service.popup = [arrivedDuringAnimation, original];
  for (const id of [1, 2, 3]) service.live[id] = { dismiss: () => dismissed.push(id) };
  service.dismissRecords([original]);
  assert.deepEqual(dismissed, [1]);
  assert.equal(service.history.length, 1);
  assert.equal(service.history[0].id, 2);
  assert.equal(service.osd.id, 3);
  assert.ok(service.live[3]);
});
