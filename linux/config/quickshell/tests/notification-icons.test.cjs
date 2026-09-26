const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');

const source = fs.readFileSync(path.join(__dirname, '../NotificationService.qml'), 'utf8');
const assetPath = '/home/test/dotfiles/linux/config/lucide/svg/';

function resolver(appLookup = null, env = {}, options = {}) {
  const service = {
    iconFileCache: {},
    iconFilePending: {},
    iconFileQueue: [],
    iconRevision: 0,
    live: options.live || {},
    requestIconFile: () => {},
  };
  const context = vm.createContext({
    service,
    Quickshell: {
      env: name => env[name] || (name === 'HOME' ? '/home/test' : ''),
      iconPath: name => name === 'custom-icon' ? '/theme/custom-icon.svg' : '',
    },
    DesktopEntries: { byId: () => appLookup, heuristicLookup: () => appLookup },
  });
  for (const name of ['resolveIcon', 'desktopEntryIcon', 'iconDescriptor', 'systemIcon', 'isBrowserIcon', 'isEphemeralSource', 'isLiveOnlySource', 'usableAppIcon', 'usableImage', 'isTeamsNotification', 'displayBody', 'focusCommand', 'lucideIcon', 'iconFor']) {
    const match = source.match(new RegExp(`  function ${name}\\([^]*?\\n  \\}`));
    assert.ok(match, `Missing QML function ${name}`);
    service[name] = vm.runInContext(`(${match[0]})`, context);
  }
  return record => JSON.parse(JSON.stringify(service.iconFor(record)));
}

function multipleFunctions(names) {
  const service = {};
  const context = vm.createContext({ service });
  for (const name of names) {
    const match = source.match(new RegExp(`  function ${name}\\([^]*?\\n  \\}`));
    assert.ok(match, `Missing QML function ${name}`);
    service[name] = vm.runInContext(`(${match[0]})`, context);
  }
  return service;
}

function displayBody(record) {
  const service = {};
  const context = vm.createContext({ service });
  for (const name of ['isBrowserIcon', 'isTeamsNotification', 'displayBody']) {
    const match = source.match(new RegExp(`  function ${name}\\([^]*?\\n  \\}`));
    assert.ok(match, `Missing QML function ${name}`);
    service[name] = vm.runInContext(`(${match[0]})`, context);
  }
  return service.displayBody(record);
}

function focusCommand(appLookup, env, isTeamsNotification = () => false) {
  const service = {};
  const context = vm.createContext({
    service,
    Quickshell: { env: name => env[name] || '' },
    DesktopEntries: { byId: () => appLookup, heuristicLookup: () => appLookup },
  });
  const match = source.match(/  function focusCommand\([^]*?\n  \}/);
  assert.ok(match, 'Missing QML function focusCommand');
  service.isTeamsNotification = isTeamsNotification;
  service.focusCommand = vm.runInContext(`(${match[0]})`, context);
  return record => JSON.parse(JSON.stringify(service.focusCommand(record)));
}

function serviceFunction(service, name) {
  const context = vm.createContext({ service });
  const match = source.match(new RegExp(`  function ${name}\\([^]*?\\n  \\}`));
  assert.ok(match, `Missing QML function ${name}`);
  service[name] = vm.runInContext(`(${match[0]})`, context);
  return service[name];
}

function activateRecord(service, id) {
  return serviceFunction(service, 'activateRecord')(id);
}

function invokeAction(service, id, index) {
  return serviceFunction(service, 'invokeAction')(id, index);
}

for (const variant of ['battery', 'battery-charging', 'battery-warning', 'battery-low', 'battery-medium', 'battery-high', 'battery-full']) {
  test(`sender-selected ${variant} is preserved and themeable`, () => {
    const iconFor = resolver({ icon: 'custom-icon' });
    for (const prefix of ['', 'file://', 'image://icon/']) {
      assert.deepEqual(iconFor({ appName: 'System', appIcon: `${prefix}${assetPath}${variant}.svg` }),
        { kind: 'lucide', source: variant });
    }
  });
}

test('specific system fallbacks precede a generic application icon', () => {
  const iconFor = resolver({ icon: 'custom-icon' });
  for (const [tag, icon] of [['battery-charging', 'battery-charging'], ['battery-critical', 'battery-warning'], ['battery-low', 'battery-low']]) {
    assert.deepEqual(iconFor({ appName: 'System', tag, summary: 'Battery' }), { kind: 'lucide', source: icon });
  }
  assert.deepEqual(iconFor({ appName: 'System', summary: 'Bluetooth device connected' }),
    { kind: 'lucide', source: 'bluetooth-connected' });
});

test('explicit imagery wins over semantic fallbacks and is not recolored', () => {
  const iconFor = resolver();
  assert.deepEqual(iconFor({ appName: 'System', tag: 'battery-low', appIcon: '/other/battery.svg' }),
    { kind: 'image', source: '/other/battery.svg' });
  assert.deepEqual(iconFor({ appName: 'System', tag: 'battery-low', appIcon: 'custom-icon' }),
    { kind: 'image', source: '/theme/custom-icon.svg' });
  assert.deepEqual(iconFor({ appName: 'System', summary: 'Bluetooth device connected', image: '/images/bluetooth.png' }),
    { kind: 'image', source: '/images/bluetooth.png' });
});

test('notification image-provider URLs retain browser image precedence', () => {
  const iconFor = resolver(null, {}, { live: { 1: {} } });
  assert.deepEqual(iconFor({ id: 1, appName: 'Firefox', appIcon: '/theme/firefox.svg', image: 'image://qsimage/notification/1' }),
    { kind: 'image', source: 'image://qsimage/notification/1' });
  assert.deepEqual(iconFor({ id: 1, appName: 'Firefox', appIcon: '/theme/firefox.svg' }),
    { kind: 'image', source: '/theme/firefox.svg' });
});

test('dead qsimage provider URLs fall back instead of rendering a broken history image', () => {
  // The notification server holds qsimage pixmaps only while the notification is
  // alive. A history record replayed later (e.g. OpenCode's app icon) would load
  // a broken image, so it must fall back to the durable theme icon or lucide.
  const record = { id: 5, appName: 'OpenCode', appIcon: 'ai.opencode.desktop', desktopEntry: 'ai.opencode.desktop', image: 'image://qsimage/16/1' };
  assert.deepEqual(resolver()(record), { kind: 'lucide', source: 'bell' });
  assert.deepEqual(resolver(null, {}, { live: { 5: {} } })(record),
    { kind: 'image', source: 'image://qsimage/16/1' });
});

test('qsimage URLs are live-only sources; durable paths are not', () => {
  const service = {};
  const isLiveOnlySource = serviceFunction(service, 'isLiveOnlySource');
  assert.equal(isLiveOnlySource('image://qsimage/16/1'), true);
  assert.equal(isLiveOnlySource('image://qsimage/notification/1'), true);
  for (const source of [
    '/usr/share/icons/hicolor/128x128/apps/firefox.png',
    'image://icon//usr/share/icons/hicolor/128x128/apps/firefox.png',
    'file:///tmp/com.google.Chrome.scoped_dir.6bBOvB/logo.png',
    '',
    null,
  ]) {
    assert.equal(isLiveOnlySource(source), false);
  }
});

test('saveHistory sanitizes live-only and ephemeral sources before persisting', () => {
  const service = multipleFunctions(['sanitizeRecord', 'isLiveOnlySource', 'isEphemeralSource']);
  const clean = service.sanitizeRecord({
    id: 7,
    appName: 'OpenCode',
    appIcon: 'ai.opencode.desktop',
    image: 'image://qsimage/16/1',
    body: 'Build finished',
  });
  assert.equal(clean.image, '');
  assert.equal(clean.appIcon, 'ai.opencode.desktop');
  assert.equal(clean.id, 7);
  assert.equal(clean.body, 'Build finished');
  const chromium = service.sanitizeRecord({ appIcon: 'file:///tmp/com.google.Chrome.scoped_dir.6bBOvB/logo.png', image: 'image://qsimage/1/1' });
  assert.equal(chromium.appIcon, '');
  assert.equal(chromium.image, '');
  const untouched = service.sanitizeRecord({ appIcon: '/usr/share/pixmaps/teams.png', image: '' });
  assert.equal(untouched.appIcon, '/usr/share/pixmaps/teams.png');
});

test('live notification image providers are not mistaken for ephemeral sources', () => {
  const service = {};
  const isEphemeralSource = serviceFunction(service, 'isEphemeralSource');
  for (const record of [
    'image://qsimage/notification/1',
    'image://icon//usr/share/icons/hicolor/128x128/apps/firefox.png',
    'file:///usr/share/pixmaps/teams.png',
  ]) {
    assert.equal(isEphemeralSource(record), false);
  }
});

test('expired Chromium temp icons fall back to the desktop entry icon', () => {
  const iconFor = resolver({ icon: 'custom-icon' });
  for (const record of [
    // Edge web notification whose scoped_dir temp files were cleaned up.
    { appName: 'Microsoft Edge', appIcon: 'file:///tmp/com.microsoft.Edge.scoped_dir.tQtfJw/logo.png', desktopEntry: 'microsoft-edge', image: 'image://icon//tmp/com.microsoft.Edge.scoped_dir.tQtfJw/icon.png' },
    // Chrome web notification without a desktop entry available.
    { appName: 'Google Chrome', appIcon: 'file:///tmp/com.google.Chrome.scoped_dir.6bBOvB/logo.png', desktopEntry: 'google-chrome' },
    // Chromium variant uses a dot-prefixed temp directory.
    { appName: 'Chromium', appIcon: 'file:///tmp/.org.chromium.Chromium.abcdef/logo.png', desktopEntry: 'chromium' },
  ]) {
    assert.deepEqual(iconFor(record), { kind: 'image', source: '/theme/custom-icon.svg' });
  }
});

test('Teams notifications sent through Chrome or Edge use the Teams icon', () => {
  const iconFor = resolver();
  for (const appIcon of [
    'google-chrome',
    'file:///tmp/com.google.Chrome.scoped_dir.UOLS13/logo.png',
    'microsoft-edge',
    'file:///tmp/com.microsoft.Edge.scoped_dir.tQtfJw/logo.png',
  ]) {
    assert.deepEqual(iconFor({
      appIcon,
      body: 'teams.cloud.microsoft\n\nNew message',
    }), {
      kind: 'image',
      source: 'file:///home/test/dotfiles/linux/config/quickshell/assets/teams.svg',
    });
  }
});

test('browser notification previews omit a hostname origin and retain the message', () => {
  assert.equal(displayBody({
    appIcon: 'google-chrome',
    body: 'teams.cloud.microsoft\nPersonal message from Ada: Can you review this?',
  }), 'Personal message from Ada: Can you review this?');
  assert.equal(displayBody({
    appName: 'Microsoft Teams',
    body: 'teams.cloud.microsoft\nPersonal message from Ada: Can you review this?',
  }), 'Personal message from Ada: Can you review this?');
  assert.equal(displayBody({
    appIcon: '',
    browserNotification: true,
    body: 'calendar.google.com\nStandup starts in 10 minutes',
  }), 'Standup starts in 10 minutes');
  assert.equal(displayBody({
    appName: 'Firefox',
    appIcon: '',
    body: 'example.com\nYour report is ready',
  }), 'Your report is ready');
  assert.equal(displayBody({
    appIcon: 'google-chrome',
    body: 'teams.cloud.microsoft\n\nI did address your comments',
  }), 'I did address your comments');
  assert.equal(displayBody({
    appIcon: 'firefox',
    body: 'example.com\n\nYour report is ready',
  }), 'Your report is ready');
  assert.equal(displayBody({
    appIcon: 'google-chrome',
    body: 'The report is ready',
  }), 'The report is ready');
  assert.equal(displayBody({
    appIcon: 'file:///tmp/com.google.Chrome.scoped_dir.UOLS13/logo.png',
    body: 'teams.cloud.microsoft\n\nI did address your comments',
  }), 'I did address your comments');
  assert.equal(displayBody({
    appIcon: 'file:///tmp/com.microsoft.Edge.scoped_dir.tQtfJw/logo.png',
    body: 'teams.cloud.microsoft\n\nI saw your message',
  }), 'I saw your message');
});

test('expired notifications focus an existing matching window instead of relaunching the app', () => {
  const entry = { startupClass: 'google-chrome' };
  assert.deepEqual(focusCommand(entry, { HYPRLAND_INSTANCE_SIGNATURE: 'test' })({ desktopEntry: 'com.google.Chrome' }),
    ['hyprctl', 'dispatch', 'focuswindow', 'class:^(google-chrome)$']);
  assert.deepEqual(focusCommand(entry, { I3SOCK: '/tmp/i3.sock' })({ desktopEntry: 'com.google.Chrome' }),
    ['i3-msg', '[class="^(?i)google-chrome$"] focus']);
  assert.deepEqual(focusCommand(entry, { HYPRLAND_INSTANCE_SIGNATURE: 'test' }, () => true)({ desktopEntry: 'com.google.Chrome' }),
    ['hyprctl', 'dispatch', 'focuswindow', 'title:^(.*Microsoft Teams.*)$']);
});

test('live notifications focus their sender before invoking its default action', () => {
  const events = [];
  const service = {
    live: { 1: { actions: [{ identifier: 'default', invoke: () => events.push('action') }] } },
    history: [{ id: 1 }],
    focusRecord: () => events.push('focus'),
  };
  assert.equal(activateRecord(service, 1), true);
  assert.deepEqual(events, ['focus', 'action']);
});

test('notification action buttons focus their sender before invoking the action', () => {
  const events = [];
  const service = {
    live: { 1: { actions: [{ identifier: 'settings', invoke: () => events.push('action') }] } },
    history: [{ id: 1 }],
    focusRecord: () => events.push('focus'),
  };
  invokeAction(service, 1, 0);
  assert.deepEqual(events, ['focus', 'action']);
});

test('system semantics do not classify unrelated notifications', () => {
  const iconFor = resolver();
  for (const record of [null, { appName: 'System', tag: 'system', summary: '15 min' },
    { appName: 'Other app', tag: 'battery-low', summary: 'Battery low' },
    { appName: 'System', tag: 'toString', summary: 'constructor' }]) {
    assert.deepEqual(iconFor(record), { kind: 'lucide', source: 'bell' });
  }
});
