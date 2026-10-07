const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');

const source = fs.readFileSync(path.join(__dirname, '../NotificationService.qml'), 'utf8');
const popupSource = fs.readFileSync(path.join(__dirname, '../NotificationPopup.qml'), 'utf8');

function serviceForTest() {
  const service = {
    history: [],
    popup: [],
    live: {},
    liveDeadlines: {},
    liveRevision: 0,
    historyLimit: 100,
    tagMap: {},
    hovered: {},
    popupLimit: 5,
    popupGroupWindow: 30,
    notificationGroupWindow: 5 * 60,
    historyGroups: [],
    historyGroupSequence: 0,
  };
  const removed = [];
  service.popupRecordRemoved = id => removed.push(id);
  const context = vm.createContext({ service, Date });
  for (const name of ['appKey', 'groupHistory', 'groupPopup', 'computeExpiry', 'effectiveUrgency', 'isTeamsNotification', 'isTeamsUrgent', 'syncPopup', 'dismissRecords', 'dismissTag', 'expireDue', 'releaseLive', 'restoreHistory', 'sanitizeRecord', 'isLiveOnlySource', 'isEphemeralSource']) {
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

test('grouping stops five minutes after the first notification', () => {
  const { service } = serviceForTest();
  const liveRecords = Array.from({ length: 11 }, (_, index) => record(index * 30)).concat(record(301));
  const groupedIds = groups => JSON.parse(JSON.stringify(groups.map(group => group.records.map(item => item.id))));

  assert.deepEqual(groupedIds(service.groupPopup(liveRecords)), [
    Array.from({ length: 11 }, (_, index) => index * 30),
    [301],
  ]);

  assert.deepEqual(groupedIds(service.groupHistory(liveRecords.slice().reverse())), [
    [301, 300, 270, 240, 210, 180, 150, 120, 90, 60, 30],
    [0],
  ]);
});

test('history group identity survives arrivals and removal of its newest record', () => {
  const { service } = serviceForTest();
  service.historyGroups = service.groupHistory([record(2), record(1)]);
  const key = service.historyGroups[0].key;
  service.historyGroups = service.groupHistory([record(3), record(2), record(1)]);
  assert.equal(service.historyGroups[0].key, key);
  service.historyGroups = service.groupHistory([record(2), record(1)]);
  assert.equal(service.historyGroups[0].key, key);
  // Splitting a former group must not give two delegates the same key.
  const split = service.groupHistory([record(2), record(9, 'B'), record(1)]);
  assert.equal(new Set(split.map(group => group.key)).size, 3);
});

test('live stacks use the same first-record cutoff as popup groups', () => {
  const { service } = serviceForTest();
  const stack = { records: [record(0), record(30), record(270), record(300)], expiring: false, service };
  const latestToast = { dismissing: false };
  const context = vm.createContext({ stack, latestToast, Math });
  const match = popupSource.match(/    function canAddRecord\([^]*?\n    \}/);
  assert.ok(match, 'Missing PopupStack.canAddRecord');
  const canAddRecord = vm.runInContext(`(${match[0]})`, context);

  assert.equal(canAddRecord(record(300)), true);
  assert.equal(canAddRecord(record(301)), false);
});

test('timeouts use milliseconds and zero stays persistent', () => {
  const { service } = serviceForTest();
  const before = Date.now();
  const defaultExpiry = service.computeExpiry({ expireTimeout: -1 }, 'normal');
  assert.ok(defaultExpiry >= before + 20000 && defaultExpiry <= Date.now() + 20000);
  const expiry = service.computeExpiry({ expireTimeout: 1000 }, 'normal');
  assert.ok(expiry >= before + 1000 && expiry <= Date.now() + 1000);
  assert.equal(service.computeExpiry({ expireTimeout: 0 }, 'normal'), 0);
  assert.equal(service.computeExpiry({ expireTimeout: 1000 }, 'critical'), 0);
});

test('low-battery notifications expose the profile action only when a lower profile is available', () => {
  const { service } = serviceForTest();
  service.buildActions = vm.runInContext(`(${source.match(/  function buildActions\([^]*?\n  \}/)[0]})`, vm.createContext({ service }));

  const notification = { actions: [], hints: { 'x-power-profile-can-lower': true } };
  assert.deepEqual(JSON.parse(JSON.stringify(service.buildActions(notification, 'battery-low'))), [
    { identifier: 'lower-profile', text: 'Use lower power profile', sourceIndex: -1 },
  ]);
  assert.deepEqual(JSON.parse(JSON.stringify(service.buildActions(notification, 'battery-critical'))), []);
  assert.deepEqual(JSON.parse(JSON.stringify(service.buildActions({ actions: [], hints: {} }, 'battery-low'))), []);
});

test('a tagged notification can be dismissed through IPC', () => {
  const { service } = serviceForTest();
  const dismissed = [];
  service.dismissRecord = id => dismissed.push(id);
  service.tagMap['lock-warning'] = { id: 42 };

  service.dismissTag('lock-warning');
  service.dismissTag('missing');

  assert.deepEqual(dismissed, [42]);
});

test('ordinary Teams critical notifications are treated as normal', () => {
  const { service } = serviceForTest();
  const teams = {
    appName: 'Chromium',
    appIcon: 'chromium',
    body: 'teams.microsoft.com\n\nCan you review this?'
  };

  assert.equal(service.isTeamsNotification(teams), true);
  assert.equal(service.effectiveUrgency(teams, 'critical'), 'normal');
  assert.ok(service.computeExpiry({ ...teams, expireTimeout: 0 }, 'normal') > Date.now());
});

test('explicitly urgent Teams notifications stay critical', () => {
  const { service } = serviceForTest();
  const teams = {
    appName: 'Microsoft Teams',
    summary: 'Urgent message from Mira',
    body: 'Please join now.'
  };

  assert.equal(service.isTeamsUrgent(teams), true);
  assert.equal(service.effectiveUrgency(teams, 'critical'), 'critical');
  assert.equal(service.computeExpiry({ ...teams, expireTimeout: 0 }, 'critical'), 0);
});

test('non-Teams critical notifications remain critical', () => {
  const { service } = serviceForTest();
  const notification = { appName: 'PagerDuty', summary: 'Incident', body: 'Production is down' };

  assert.equal(service.isTeamsNotification(notification), false);
  assert.equal(service.effectiveUrgency(notification, 'critical'), 'critical');
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

test('expiry covers hidden and trimmed notifications while preserving hover and persistent deadlines', () => {
  const { service } = serviceForTest();
  const expired = [];
  service.now = Date.now();
  service.doNotDisturb = true;
  // No popup or history entries: lifetime must not depend on either list.
  for (const id of [1, 2, 3, 4]) {
    service.live[id] = { expire: () => expired.push(id) };
    service.liveDeadlines[id] = service.now - 1;
  }
  service.liveDeadlines[3] = 0;
  service.hovered[4] = true;
  service.expireDue();
  assert.deepEqual(expired, [1, 2]);
  assert.deepEqual(Object.keys(service.live), ['3', '4']);
  delete service.hovered[4];
  service.expireDue();
  assert.deepEqual(expired, [1, 2, 4]);
  assert.deepEqual(Object.keys(service.liveDeadlines), ['3']);
});

test('DND suppression survives reconciliation and does not dismiss native actions or OSDs', () => {
  const { service } = serviceForTest();
  const settings = {};
  service.setDoNotDisturb = vm.runInContext(`(${source.match(/  function setDoNotDisturb\([^]*?\n  \}/)[0]})`, vm.createContext({ service, settings }));
  service.saveHistory = () => {};
  service.history = [record(1)];
  service.live[1] = { dismiss: () => assert.fail('DND must not dismiss') };
  service.osd = { id: 'volume' };
  service.syncPopup();
  service.setDoNotDisturb(true);
  service.history.unshift({ ...record(2), popupSuppressed: true });
  service.live[2] = {};
  service.syncPopup();
  assert.equal(service.popup.length, 0);
  assert.equal(service.osd.id, 'volume');
  assert.ok(service.live[1]);
  service.setDoNotDisturb(false);
  assert.equal(service.popup.length, 0);
  service.history.unshift(record(3));
  service.live[3] = {};
  service.syncPopup();
  assert.deepEqual(Array.from(service.popup, item => item.id), [3]);
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

test('restored history skips malformed records and normalizes valid neighbors', () => {
  const { service } = serviceForTest();
  const restored = service.restoreHistory([null, [], { id: 1 }, { id: {}, time: 1 },
    { id: 2, time: 123, summary: 'Keep me', urgency: 'invalid', actions: null, body: {}, image: 'image://qsimage/old' },
    { id: '2', time: 123 }, { id: 3, time: 124, appName: 'App', body: 'Still here' }]);
  assert.deepEqual(Array.from(restored, record => record.id), [2, 3]);
  assert.equal(restored[0].body, '');
  assert.equal(restored[0].image, '');
  assert.equal(restored[0].appName, 'Unknown');
  assert.equal(restored[0].urgency, 'normal');
  assert.equal(restored[0].actions.length, 0);
  assert.equal(restored[1].body, 'Still here');
  assert.equal(service.restoreHistory({}).length, 0);
});

test('native closure updates observers and a stale closure cannot release a replacement', () => {
  const { service } = serviceForTest();
  const original = {};
  const replacement = {};
  service.live[1] = replacement;
  service.liveDeadlines[1] = 123;
  service.hovered[1] = true;
  service.tagMap.tag = replacement;
  service.releaseLive(1, original);
  assert.equal(service.live[1], replacement);
  assert.equal(service.liveRevision, 0);
  assert.equal(service.hovered[1], true);
  service.releaseLive(1, replacement);
  assert.equal(service.live[1], undefined);
  assert.equal(service.tagMap.tag, undefined);
  assert.equal(service.liveDeadlines[1], undefined);
  assert.equal(service.liveRevision, 1);
});
