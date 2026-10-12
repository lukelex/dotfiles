const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');

const source = fs.readFileSync(path.join(__dirname, '../NotificationService.qml'), 'utf8');

function preferences(names, values = {}, globals = {}) {
  const settings = {};
  const service = { ...values };
  const context = vm.createContext({ service, settings, Date, ...globals });
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

test('popup privacy removes text, images and action labels without modifying retained history', () => {
  const { service, settings } = preferences(['popupDisplayRecord', 'setPopupPreviews', 'setLockScreenPrivacy']);
  const record = { id: 1, appName: 'Chat', desktopEntry: 'chat', summary: 'Secret title', body: 'Secret body',
    appIcon: 'private-photo.png', image: 'image://qsimage/private', actions: [{ text: 'Reply to someone' }], value: 50 };
  service.popupPreviews = true;
  assert.equal(service.popupDisplayRecord(record), record);
  service.setPopupPreviews(false);
  service.popupPreviews = settings.popupPreviews;
  const redacted = service.popupDisplayRecord(record);
  assert.equal(redacted.summary, 'New notification');
  assert.equal(redacted.appName, 'Chat');
  assert.equal(redacted.desktopEntry, 'chat');
  assert.equal(redacted.id, 1);
  assert.equal(redacted.body, '');
  assert.equal(redacted.image, '');
  assert.equal(redacted.appIcon, '');
  assert.equal(redacted.actions.length, 0);
  assert.equal(redacted.value, -1);
  assert.equal(record.summary, 'Secret title');
  assert.equal(record.actions.length, 1);
  let synced = 0;
  settings.sync = () => synced++;
  service.setLockScreenPrivacy('redact');
  service.setLockScreenPrivacy('bad-mode');
  assert.equal(settings.lockScreenPrivacy, 'redact');
  assert.equal(synced, 1);
});

test('popup duration sets default deadlines without overriding critical or explicit sender lifetimes', () => {
  const now = 1234567890000;
  const { service, settings } = preferences(['computeExpiry', 'setPopupDurationSeconds'], {
    popupDurationSeconds: 20, isTeamsNotification: notification => notification.teams === true
  }, { Date: { now: () => now } });
  for (const seconds of [0, 5, 10, 20, 30, 60]) {
    service.setPopupDurationSeconds(seconds);
    service.popupDurationSeconds = settings.popupDurationSeconds;
    const expected = seconds ? now + seconds * 1000 : 0;
    assert.equal(service.computeExpiry({ expireTimeout: -1 }, 'normal'), expected);
    assert.equal(service.computeExpiry({ expireTimeout: 0, teams: true }, 'normal'), expected);
    assert.equal(service.computeExpiry({ expireTimeout: 1500 }, 'normal'), now + 1500);
    assert.equal(service.computeExpiry({ expireTimeout: 0 }, 'normal'), 0);
    assert.equal(service.computeExpiry({ expireTimeout: -1 }, 'critical'), 0);
  }
  service.setPopupDurationSeconds(-1);
  assert.equal(settings.popupDurationSeconds, 60);
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

function schedule(initialDate) {
  let now = initialDate.getTime();
  class Clock extends Date {
    constructor(...args) { super(...(args.length ? args : [now])); }
    static now() { return now; }
  }
  const fixture = preferences(['dndIntervals', 'nextDndBoundary', 'refreshDndSchedule',
    'setDndSchedule', 'setDoNotDisturb', 'applyDoNotDisturb', 'formatScheduleTime', 'isDndSuppressed', 'suppressDndRecords'], {
    preferencesLoaded: true, doNotDisturb: false, history: [{ id: 1 }], pendingPopupRecords: [{ id: 1 }],
    notificationSound: { running: true }, syncPopup() {}, saveHistory() {}
  }, { Date: Clock, Qt: { formatDateTime: date => date.toISOString() } });
  Object.assign(fixture.settings, {
    dndScheduleEnabled: false, dndStartMinutes: 1320, dndEndMinutes: 480,
    dndScheduleDays: 127, dndOverrideUntil: 0, dndOverrideEnabled: false, doNotDisturb: false
  });
  for (const key of ['dndScheduleEnabled', 'dndStartMinutes', 'dndEndMinutes', 'dndScheduleDays'])
    Object.defineProperty(fixture.service, key, { get: () => fixture.settings[key] });
  fixture.advance = date => { now = date.getTime(); fixture.service.refreshDndSchedule(); };
  return fixture;
}

test('weekday quiet hours cross midnight based on the start day, with exclusive end boundaries', () => {
  const { service, advance } = schedule(new Date(2026, 9, 16, 21, 59)); // Friday
  service.setDndSchedule(true, 1320, 480, 31);
  assert.equal(service.doNotDisturb, false);
  advance(new Date(2026, 9, 16, 22));
  assert.equal(service.doNotDisturb, true);
  assert.equal(service.notificationSound.running, false);
  assert.equal(service.history[0].popupSuppressed, true);
  advance(new Date(2026, 9, 17, 7, 59));
  assert.equal(service.doNotDisturb, true);
  advance(new Date(2026, 9, 17, 8));
  assert.equal(service.doNotDisturb, false);
  assert.equal(service.history[0].popupSuppressed, true);
  assert.equal(service.nextDndBoundary(new Date(2026, 9, 17, 8)), new Date(2026, 9, 19, 22).getTime());
  advance(new Date(2026, 9, 17, 23));
  assert.equal(service.doNotDisturb, false);
});

test('manual overrides survive refresh/reload and expire at the next boundary', () => {
  const { service, settings, advance } = schedule(new Date(2026, 9, 12, 23));
  service.setDndSchedule(true, 1320, 480, 127);
  service.setDoNotDisturb(false);
  assert.equal(service.doNotDisturb, false);
  assert.equal(settings.dndOverrideUntil, new Date(2026, 9, 13, 8).getTime());
  service.doNotDisturb = true; // Reconstructed runtime, persisted settings intact.
  service.refreshDndSchedule();
  assert.equal(service.doNotDisturb, false);
  advance(new Date(2026, 9, 13, 8));
  assert.equal(settings.dndOverrideUntil, 0);
  assert.equal(service.doNotDisturb, false);
  service.setDoNotDisturb(true);
  assert.equal(settings.dndOverrideUntil, new Date(2026, 9, 13, 22).getTime());
  advance(new Date(2026, 9, 14, 9)); // Resume after crossing both boundaries.
  assert.equal(service.doNotDisturb, false);
  assert.equal(settings.dndOverrideUntil, 0);
});

test('schedule validates times, supports daytime/weekend schedules and returns to manual control', () => {
  const { service, settings, advance } = schedule(new Date(2026, 9, 17, 10));
  assert.equal(service.setDndSchedule(true, 9 * 60, 17 * 60, 96), true);
  assert.equal(service.doNotDisturb, true);
  assert.equal(service.setDndSchedule(true, 540, 540, 96), false);
  assert.equal(service.setDndSchedule(true, -1, 540, 96), false);
  assert.equal(service.setDndSchedule(true, 1440, 540, 96), false);
  assert.equal(service.setDndSchedule(true, 540, 1020, 0), false);
  assert.equal(settings.dndEndMinutes, 1020);
  service.setDndSchedule(false, 540, 1020, 96);
  assert.equal(service.doNotDisturb, true);
  advance(new Date(2026, 9, 19, 18));
  assert.equal(service.doNotDisturb, true);
  service.setDoNotDisturb(false);
  assert.equal(service.doNotDisturb, false);
  assert.equal(service.formatScheduleTime(5), '00:05');
  assert.equal(service.formatScheduleTime(1439), '23:59');
});

test('local calendar boundaries handle spring-forward and fall-back overnight schedules', () => {
  const previous = process.env.TZ;
  process.env.TZ = 'America/New_York';
  try {
    for (const [date, hours] of [[new Date(2026, 2, 7, 22), 9], [new Date(2026, 9, 31, 22), 11]]) {
      const { service } = schedule(date);
      service.setDndSchedule(true, 1320, 480, 127);
      assert.equal(service.doNotDisturb, true);
      assert.equal(service.nextDndBoundary(date) - date.getTime(), hours * 3600000);
    }
  } finally {
    if (previous === undefined) delete process.env.TZ;
    else process.env.TZ = previous;
  }
});

test('critical DND exceptions respect app blocking, app sound, global mute and sender silence', () => {
  for (const urgency of ['normal', 'critical']) {
    for (const enabled of [false, true]) {
      for (const sound of [false, true]) {
        for (const muted of [false, true]) {
          for (const silent of [false, true]) {
            const { service } = preferences(['handleNotification', 'playNotificationSound', 'isDndSuppressed', 'syncPopup', 'releaseLive'], {
              doNotDisturb: true, allowCriticalDuringDnd: true, notificationSoundsMuted: muted,
              notificationSound: { running: false }, notificationSoundTimer: { running: false, start() {} },
              live: {}, liveDeadlines: {}, liveRevision: 0, hovered: {}, tagMap: {},
              popup: [], history: [], pendingPopupRecords: [], popupLimit: 5,
              refreshDndSchedule() {}, isSystemOsd: () => false,
              trackApplication: () => ({ enabled, sound }), popupRecordRemoved() {}
            }, { popupUpdateTimer: { start() {} } });
            service.buildRecord = notification => ({ id: notification.id, urgency,
              expiresAt: Date.now() + 20000, popupSuppressed: service.isDndSuppressed({ urgency }) });
            service.addHistory = record => service.history.push(record);
            service.handleNotification({ id: 1, hints: { 'suppress-sound': silent }, closed: { connect() {} }, dismiss() {} });
            service.syncPopup();
            const allowed = enabled && urgency === 'critical';
            assert.equal(service.popup.length, allowed ? 1 : 0);
            assert.equal(service.history.length, enabled ? 1 : 0);
            assert.equal(service.notificationSound.running, allowed && sound && !muted && !silent);
          }
        }
      }
    }
  }
});

test('critical exception changes reconcile active popups without replaying suppressed records', () => {
  const { service, settings } = preferences(['setAllowCriticalDuringDnd', 'applyDoNotDisturb', 'isDndSuppressed', 'suppressDndRecords', 'syncPopup'], {
    doNotDisturb: false, notificationSoundIsCritical: true, notificationSound: { running: true },
    history: [{ id: 1, urgency: 'normal', expiresAt: 0 }, { id: 2, urgency: 'critical', expiresAt: 0 }],
    pendingPopupRecords: [], live: { 1: {}, 2: {} }, popup: [], popupLimit: 5, hovered: {},
    saveHistory() {}, popupRecordRemoved() {}
  });
  settings.allowCriticalDuringDnd = true;
  Object.defineProperty(service, 'allowCriticalDuringDnd', { get: () => settings.allowCriticalDuringDnd });
  service.applyDoNotDisturb(true);
  assert.deepEqual(Array.from(service.popup, record => record.id), [2]);
  assert.equal(service.notificationSound.running, true);
  service.setAllowCriticalDuringDnd(false);
  assert.equal(service.popup.length, 0);
  assert.equal(service.notificationSound.running, false);
  service.setAllowCriticalDuringDnd(true);
  service.applyDoNotDisturb(false);
  assert.equal(service.popup.length, 0);
  assert.equal(service.history.length, 2);
  assert.equal(Object.keys(service.live).length, 2);
});
