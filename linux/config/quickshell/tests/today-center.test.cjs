const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');

const source = fs.readFileSync(path.join(__dirname, '../TodayCenter.qml'), 'utf8');

function fixture() {
  const later = [];
  const animation = () => ({ running: false, stop() { this.running = false; }, start() { this.running = true; } });
  const context = vm.createContext({
    popup: { today: new Date(2024, 1, 29, 12), displayedMonth: new Date(2023, 11, 1, 12),
      pinned: false, closing: false, promotionPending: false, promotionSnapshot: null,
      promotionWindow: null, pinRequest: 0, weather: { refreshes: 0, refresh() { this.refreshes++; } },
      quote: { refreshes: 0, refresh() { this.refreshes++; } } },
    preview: { visible: false, contentItem: { Window: { window: { raise() {} } } } },
    pinnedPopup: { visible: false, open() { this.visible = true; context.onOpened(); }, close() { this.visible = false; } },
    scroll: { contentY: 80 }, content: {
      opacity: 0, y: 10, forceActiveFocus() {}, nativeWindow: {},
      grabToImage(callback) {
        later.push(() => {
          callback({ url: 'image://test/snapshot' });
          if (context.popup.promotionSnapshot)
            context.Qt.callLater(context.popup.openPinned, context.popup.pinRequest); // Image.Ready.
        });
        return true;
      },
    },
    openAnim: animation(), closeAnim: animation(), closeTimer: { stop() {}, restart() {} },
    Qt: { callLater(callback, ...args) { later.push(() => callback(...args)); } },
  });
  Object.defineProperty(context.popup, 'visible', { get: () => context.preview.visible || context.pinnedPopup.visible });
  for (const match of source.matchAll(/^  function (\w+)\(([^\n]*)\) \{\n([\s\S]*?)^  \}/gm)) {
    context.popup[match[1]] = vm.runInContext(`(function(${match[2]}) {\n${match[3]}\n})`, context);
  }
  const opened = source.match(/^    function open\(\) \{\n([\s\S]*?)^    \}/m);
  assert.ok(opened, 'Missing pinned popup open function');
  context.onOpened = vm.runInContext(`(function() {\n${opened[1]}\n})`, context);
  const frame = source.match(/^    function onFrameSwapped\(\) \{\n([\s\S]*?)^    \}/m);
  assert.ok(frame, 'Missing native frame-ready handler');
  const frameSwapped = vm.runInContext(`(function() {\n${frame[1]}\n})`, context);
  return { ...context, frameSwapped, flush() { while (later.length) later.shift()(); } };
}

function dateParts(date) {
  return [date.getFullYear(), date.getMonth() + 1, date.getDate()];
}

function loadFunction(name, globals) {
  const match = source.match(new RegExp(`  function ${name}\\([^]*?\\n  \\}`));
  assert.ok(match, `Missing TodayCenter function ${name}`);
  return vm.runInNewContext(`(${match[0]})`, globals);
}

test('media player selection prefers a controllable player that is currently playing', () => {
  const pausedPlayer = { ready: true, canControl: true, isPlaying: false, trackTitle: 'Paused song' };
  const playingPlayer = { ready: true, canControl: true, isPlaying: true, trackTitle: 'Current song' };
  const unavailablePlayer = { ready: false, canControl: true, isPlaying: true, trackTitle: 'Not ready' };
  const Mpris = { players: { values: [unavailablePlayer, pausedPlayer, playingPlayer] } };
  const popup = { selectedMediaPlayerKey: '', mediaPlayerKey: player => player.dbusName,
    availableMediaPlayers: loadFunction('availableMediaPlayers', { Mpris }) };
  popup.selectMediaPlayer = loadFunction('selectMediaPlayer', { popup });

  assert.equal(popup.selectMediaPlayer(), playingPlayer);
  popup.selectedMediaPlayerKey = pausedPlayer.dbusName;
  assert.equal(popup.selectMediaPlayer(), pausedPlayer);
  Mpris.players.values = [pausedPlayer];
  popup.selectedMediaPlayerKey = '';
  assert.equal(popup.selectMediaPlayer(), pausedPlayer);
  Mpris.players.values = [];
  assert.equal(popup.selectMediaPlayer(), null);
  assert.match(source, /readonly property real width: Math\.max\(1, Math\.min\(640,/);
  assert.match(source, /visible: popup\.activeMediaPlayer !== null/);
  for (const icon of ['skip-back', 'play', 'pause', 'skip-forward']) {
    assert.ok(fs.existsSync(path.join(__dirname, '../../lucide/svg', `${icon}.svg`)), `${icon} icon exists`);
  }
  assert.match(source, /iconName: "skip-back"/);
  assert.match(source, /iconName: popup\.activeMediaPlayer && popup\.activeMediaPlayer\.isPlaying \? "pause" : "play"/);
  assert.match(source, /iconName: "skip-forward"/);
});

test('media source switching exposes at most two alternatives and hands playback over', () => {
  const calls = [];
  const playing = { dbusName: 'playing', ready: true, canControl: true, isPlaying: true,
    canPause: true, pause: () => calls.push('pause current') };
  const target = { dbusName: 'target', ready: true, canControl: true, isPlaying: false,
    canRaise: true, raise: () => calls.push('raise target'), canPlay: true,
    play: () => calls.push('play target') };
  const extras = [target, { dbusName: 'third', isPlaying: false, trackTitle: 'Third track' },
    { dbusName: 'fourth', isPlaying: false, trackTitle: 'Fourth track' }];
  playing.trackTitle = 'Current track';
  target.trackTitle = 'Target track';
  const popup = { selectedMediaPlayerKey: '', mediaPlayerKey: player => player.dbusName,
    availableMediaPlayers: () => [playing, ...extras] };
  popup.selectMediaPlayer = loadFunction('selectMediaPlayer', { popup });
  Object.defineProperty(popup, 'activeMediaPlayer', { get: () => popup.selectMediaPlayer() });
  popup.otherMediaPlayers = loadFunction('otherMediaPlayers', { popup });
  popup.activateMediaPlayer = loadFunction('activateMediaPlayer', { popup });

  assert.deepEqual(popup.otherMediaPlayers(), extras.slice(0, 2));
  popup.availableMediaPlayers = () => [playing, { ...playing },
    { dbusName: 'duplicate browser', trackTitle: 'Current track', isPlaying: false },
    { dbusName: 'empty', trackTitle: '', isPlaying: false },
    ...extras, { dbusName: 'other playing', isPlaying: true }];
  assert.deepEqual(popup.otherMediaPlayers(), extras.slice(0, 2));
  popup.activateMediaPlayer(target);
  assert.equal(popup.selectedMediaPlayerKey, 'target');
  assert.deepEqual(calls, ['pause current', 'raise target', 'play target']);
  assert.match(source, /height: cardHeight \+ \(popup\.inactiveMediaPlayers\.length > 0 \? 60 : 0\)/);
  assert.match(source, /flickableDirection: Flickable\.HorizontalFlick/);
  assert.match(source, /popup\.activateMediaPlayer\(modelData\)/);
  assert.match(source, /inactivePlayerButton\.modelData\.trackTitle \|\| "No track information"/);
  assert.match(source, /inactivePlayerButton\.modelData\.trackArtist \|\| "Unknown artist"/);
});

test('media playback toggle respects player capabilities', () => {
  const calls = [];
  const toggleMediaPlayback = loadFunction('toggleMediaPlayback', {});
  toggleMediaPlayback({ canTogglePlaying: true, togglePlaying: () => calls.push('toggle') });
  toggleMediaPlayback({ canTogglePlaying: false, isPlaying: true, canPause: true, pause: () => calls.push('pause') });
  toggleMediaPlayback({ canTogglePlaying: false, isPlaying: false, canPlay: true, play: () => calls.push('play') });
  assert.deepEqual(calls, ['toggle', 'pause', 'play']);
});

test('MPRIS timeline needs valid position and duration, and only seeks when supported', () => {
  const player = { positionSupported: true, lengthSupported: true, length: 245, position: 61, canSeek: true };
  const popup = { hasMediaProgress: loadFunction('hasMediaProgress', {}) };
  const progress = loadFunction('mediaProgress', { popup });
  const seek = loadFunction('seekMediaPlayer', { popup });
  const format = loadFunction('formatMediaTime', {});

  assert.equal(popup.hasMediaProgress(player), true);
  assert.equal(progress(player), 61 / 245);
  seek(player, 0.5);
  assert.equal(player.position, 122.5);
  seek(player, 2);
  assert.equal(player.position, 245);
  player.canSeek = false;
  seek(player, 0);
  assert.equal(player.position, 245);
  player.lengthSupported = false;
  assert.equal(popup.hasMediaProgress(player), false);
  player.lengthSupported = true;
  player.length = 0;
  assert.equal(popup.hasMediaProgress(player), false);
  assert.equal(format(61.8), '1:01');
  assert.equal(format(3661), '1:01:01');
  assert.equal(format(NaN), '0:00');
  assert.match(source, /running: popup\.visible && popup\.hasMediaProgress\(popup\.activeMediaPlayer\) && popup\.activeMediaPlayer\.isPlaying/);
  assert.match(source, /onTriggered: popup\.activeMediaPlayer\.positionChanged\(\)/);
});

test('Monday-first calendar has 42 consecutive dates, including leap day and adjacent months', () => {
  const { popup } = fixture();
  popup.resetMonth();
  const cells = Array.from({ length: 42 }, (_, i) => popup.calendarDate(i));
  assert.equal(cells[0].getDay(), 1);
  assert.deepEqual(dateParts(cells[0]), [2024, 1, 29]);
  assert.deepEqual(dateParts(cells[41]), [2024, 3, 10]);
  assert.equal(cells.filter(date => date.getMonth() === 1).length, 29);
  assert.equal(cells.filter(date => popup.isToday(date)).length, 1);
  assert.equal(popup.isToday(new Date(2023, 1, 28, 12)), false);
  assert.equal(popup.isToday(new Date(2024, 0, 29, 12)), false);
  for (let i = 1; i < cells.length; i++) {
    const next = new Date(cells[i - 1]);
    next.setDate(next.getDate() + 1);
    assert.deepEqual(dateParts(cells[i]), dateParts(next));
  }
});

test('month navigation pins first and rolls over years without end-of-month overflow', () => {
  const f = fixture();
  f.popup.requestOpen();
  f.popup.displayedMonth = new Date(2024, 11, 31, 12);
  f.popup.changeMonth(1);
  assert.equal(f.popup.pinned, true);
  assert.deepEqual(dateParts(f.popup.displayedMonth), [2025, 1, 1]);
  f.flush();
  f.popup.changeMonth(-1);
  assert.deepEqual(dateParts(f.popup.displayedMonth), [2024, 12, 1]);
  f.popup.displayedMonth = new Date(2023, 1, 1, 12);
  assert.equal(Array.from({ length: 42 }, (_, i) => f.popup.calendarDate(i)).filter(d => d.getMonth() === 1).length, 28);
});

test('fresh open resets month and refreshes once; hover-to-pin and repeated opens preserve browsing', () => {
  const f = fixture();
  f.popup.requestOpen();
  assert.deepEqual(dateParts(f.popup.displayedMonth), [2024, 2, 1]);
  assert.equal(f.scroll.contentY, 0);
  f.popup.changeMonth(2);
  // Repeated clicks during the deferred handoff must preserve the browsing session.
  f.popup.requestOpen(true);
  assert.deepEqual(dateParts(f.popup.displayedMonth), [2024, 4, 1]);
  assert.equal(f.popup.weather.refreshes, 1);
  f.flush();
  f.popup.today = new Date(2024, 2, 1, 12);
  f.popup.requestOpen();
  assert.deepEqual(dateParts(f.popup.displayedMonth), [2024, 4, 1]);
  f.popup.goToday();
  assert.deepEqual(dateParts(f.popup.displayedMonth), [2024, 3, 1]);
  f.flush();
  f.popup.requestClose(true);
  f.popup.pinned = false; // Native onClosed.
  f.popup.requestOpen();
  assert.deepEqual(dateParts(f.popup.displayedMonth), [2024, 3, 1]);
  assert.equal(f.popup.weather.refreshes, 2);
});

test('preview exit reversal retains browsing and cancels the opposing animation', () => {
  const f = fixture();
  f.popup.requestOpen();
  f.popup.displayedMonth = new Date(2025, 0, 1, 12);
  f.popup.requestClose();
  assert.equal(f.closeAnim.running, true);
  f.popup.requestOpen();
  assert.equal(f.closeAnim.running, false);
  assert.equal(f.openAnim.running, true);
  assert.deepEqual(dateParts(f.popup.displayedMonth), [2025, 1, 1]);
  assert.equal(f.popup.weather.refreshes, 1);
});

test('first calendar click keeps the preview visible and does not replay its entrance', () => {
  const f = fixture();
  f.popup.requestOpen();
  f.content.opacity = 1;
  f.content.y = 0;
  f.openAnim.running = false;
  f.popup.changeMonth(1);
  assert.equal(f.preview.visible, true);
  assert.equal(f.popup.visible, true);
  assert.equal(f.pinnedPopup.visible, false);
  f.flush();
  assert.equal(f.preview.visible, true, 'Native opened is not a painted-frame guarantee');
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
  f.popup.changeMonth(1);
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
  f.popup.changeMonth(1);
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

test('forecast city date is parsed at local noon and timestamp age follows the minute clock', () => {
  const { popup } = fixture();
  for (const day of ['2024-03-10', '2024-11-03', '2025-01-01']) {
    const parsed = popup.forecastDate(day);
    assert.equal(parsed.getHours(), 12);
    assert.equal(dateParts(parsed).map((n, i) => i ? String(n).padStart(2, '0') : n).join('-'), day);
  }
  popup.weather.updatedAt = popup.today.getTime() / 1000 - 120;
  assert.equal(popup.updatedText(), 'Updated 2 min ago');
  popup.today = new Date(popup.today.getTime() + 60000);
  assert.equal(popup.updatedText(), 'Updated 3 min ago');
});
