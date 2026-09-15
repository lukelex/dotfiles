const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');

const source = fs.readFileSync(path.join(__dirname, '../NotificationService.qml'), 'utf8');
const assetPath = '/home/test/dotfiles/linux/config/lucide/svg/';

function resolver(appLookup = null) {
  const service = {};
  const context = vm.createContext({
    service,
    Quickshell: {
      env: () => '/home/test',
      iconPath: name => name === 'custom-icon' ? '/theme/custom-icon.svg' : '',
    },
    DesktopEntries: { byId: () => null, heuristicLookup: () => appLookup },
  });
  for (const name of ['resolveIcon', 'desktopEntryIcon', 'iconDescriptor', 'systemIcon', 'isBrowserIcon', 'isTeamsNotification', 'lucideIcon', 'iconFor']) {
    const match = source.match(new RegExp(`  function ${name}\\([^]*?\\n  \\}`));
    assert.ok(match, `Missing QML function ${name}`);
    service[name] = vm.runInContext(`(${match[0]})`, context);
  }
  return record => JSON.parse(JSON.stringify(service.iconFor(record)));
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

test('Teams notifications sent through Chrome use the Teams icon', () => {
  const iconFor = resolver();
  assert.deepEqual(iconFor({
    appIcon: 'google-chrome',
    body: 'teams.cloud.microsoft\n\nNew message',
  }), {
    kind: 'image',
    source: 'file:///home/test/dotfiles/linux/config/quickshell/assets/teams.svg',
  });
});

test('system semantics do not classify unrelated notifications', () => {
  const iconFor = resolver();
  for (const record of [null, { appName: 'System', tag: 'system', summary: '15 min' },
    { appName: 'Other app', tag: 'battery-low', summary: 'Battery low' },
    { appName: 'System', tag: 'toString', summary: 'constructor' }]) {
    assert.deepEqual(iconFor(record), { kind: 'lucide', source: 'bell' });
  }
});
