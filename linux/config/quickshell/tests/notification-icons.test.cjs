const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');

const source = fs.readFileSync(path.join(__dirname, '../NotificationService.qml'), 'utf8');
const assetPath = '/home/test/dotfiles/linux/config/lucide/svg/';

function resolver(appLookup = null, env = {}) {
  const service = {};
  const context = vm.createContext({
    service,
    Quickshell: {
      env: name => env[name] || (name === 'HOME' ? '/home/test' : ''),
      iconPath: name => name === 'custom-icon' ? '/theme/custom-icon.svg' : '',
    },
    DesktopEntries: { byId: () => appLookup, heuristicLookup: () => appLookup },
  });
  for (const name of ['resolveIcon', 'desktopEntryIcon', 'iconDescriptor', 'systemIcon', 'isBrowserIcon', 'isEphemeralSource', 'isTeamsNotification', 'displayBody', 'focusCommand', 'lucideIcon', 'iconFor']) {
    const match = source.match(new RegExp(`  function ${name}\\([^]*?\\n  \\}`));
    assert.ok(match, `Missing QML function ${name}`);
    service[name] = vm.runInContext(`(${match[0]})`, context);
  }
  return record => JSON.parse(JSON.stringify(service.iconFor(record)));
}

function displayBody(record) {
  const service = {};
  const context = vm.createContext({ service });
  for (const name of ['isBrowserIcon', 'displayBody']) {
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

for (const variant of ['battery', 'battery-charging', 'battery-warning', 'battery-low', 'battery-medium', 'battery-full']) {
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
  const iconFor = resolver();
  assert.deepEqual(iconFor({ appName: 'Firefox', appIcon: '/theme/firefox.svg', image: 'image://qsimage/notification/1' }),
    { kind: 'image', source: 'image://qsimage/notification/1' });
  assert.deepEqual(iconFor({ appName: 'Firefox', appIcon: '/theme/firefox.svg' }),
    { kind: 'image', source: '/theme/firefox.svg' });
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
