const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');

const source = fs.readFileSync(path.join(__dirname, '../NotificationService.qml'), 'utf8');

function preferences(names, values = {}) {
  const settings = {};
  const service = { ...values };
  const context = vm.createContext({ service, settings, Date });
  for (const name of names) {
    const match = source.match(new RegExp(`  function ${name}\\([^]*?\\n  \\}`));
    assert.ok(match, name);
    service[name] = vm.runInContext(`(${match[0]})`, context);
  }
  return { service, settings };
}

test('popup placement selects named/focused monitors and falls back after hot unplug', () => {
  const { service, settings } = preferences(['setPopupCorner', 'setPopupMonitor', 'popupScreenMatches']);
  const screens = [{ name: 'DP-1' }, { name: 'eDP-1' }];
  service.setPopupCorner('bottom-left');
  service.setPopupCorner('invalid');
  assert.equal(settings.popupCorner, 'bottom-left');
  service.setPopupMonitor('DP-1');
  service.popupMonitor = settings.popupMonitor;
  assert.equal(service.popupScreenMatches('DP-1', screens, 'eDP-1'), true);
  assert.equal(service.popupScreenMatches('eDP-1', screens, 'eDP-1'), false);
  assert.equal(service.popupScreenMatches('eDP-1', screens.slice(1), 'eDP-1'), true);
  assert.equal(service.popupScreenMatches('eDP-1', screens.slice(1), ''), true);
  assert.equal(service.popupMonitor, 'DP-1');
  service.popupMonitor = 'focused';
  assert.equal(service.popupScreenMatches('DP-1', screens, 'eDP-1'), false);
  assert.equal(service.popupScreenMatches('eDP-1', screens, 'eDP-1'), true);
  service.popupMonitor = 'all';
  assert.equal(service.popupScreenMatches('DP-1', screens, ''), true);
  assert.equal(service.popupScreenMatches('eDP-1', screens, ''), true);
});

test('retention removes only old inactive history without touching native lifecycle or app preferences', () => {
  const now = Date.now() / 1000;
  let saves = 0;
  const { service, settings } = preferences(['pruneHistory', 'setHistoryRetentionDays'], {
    historyRetentionDays: 7,
    history: [
      { id: 1, time: now - 8 * 86400 },
      { id: 2, time: now - 6 * 86400 },
      { id: 3, time: now - 30 * 86400 },
      { id: 4, time: now - 30 * 86400 }
    ],
    live: { 3: { persistent: true } },
    liveDeadlines: { 3: 0 },
    hovered: { 4: true },
    applications: [{ key: 'chat', sound: false }],
    groupHistory: records => [{ key: 'survivor', records }],
    saveHistory: () => saves++
  });
  service.historyBeingRead = true;
  service.pruneHistory();
  assert.equal(service.history.length, 4);
  assert.equal(saves, 0);
  service.historyBeingRead = false;
  service.pruneHistory();
  assert.deepEqual(Array.from(service.history, record => record.id), [2, 3, 4]);
  assert.equal(saves, 1);
  assert.equal(service.liveDeadlines[3], 0);
  assert.equal(service.applications[0].sound, false);
  service.pruneHistory();
  assert.equal(saves, 1);
  delete service.live[3];
  delete service.hovered[4];
  service.pruneHistory();
  assert.deepEqual(Array.from(service.history, record => record.id), [2]);
  service.setHistoryRetentionDays(30);
  service.setHistoryRetentionDays(-1);
  assert.equal(settings.historyRetentionDays, 30);
  service.historyRetentionDays = 0;
  service.history.push({ id: 5, time: 0 });
  service.pruneHistory();
  assert.equal(service.history.length, 2);
});
