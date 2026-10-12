const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');
const read = name => fs.readFileSync(path.resolve(__dirname, '..', name), 'utf8');

test('settings gear matches notification header sizing and supplies tooltip/accessibility', () => {
  const source = read('HeaderSettingsButton.qml');
  assert.match(source, /width: 32\s+height: 32/);
  assert.match(source, /width: 16\s+height: 16/);
  assert.match(source, /Accessible.name: description/);
  assert.match(source, /Controls.ToolTip/);
  assert.match(source, /source: button.controller.icon\("settings"\)/);
});

test('gear opens direct settings or its menu after preparing the parent popup', () => {
  const source = read('HeaderSettingsButton.qml');
  const block = source.match(/  onClicked: \{([^]*?)\n  \}/)[1];
  for (const options of [[], [{ text: 'Network settings' }]]) {
    const calls = [];
    vm.runInNewContext(`(() => { ${block} })()`, {
      options, opening: () => calls.push('prepare'), activated: () => calls.push('settings'),
      menu: { popup: () => calls.push('menu') },
    });
    assert.deepEqual(calls, ['prepare', options.length ? 'menu' : 'settings']);
  }
});

test('audio and control settings are in headers, not large footer actions', () => {
  const audio = read('AudioOutputCenter.qml');
  const control = read('ControlCenter.qml');
  assert.match(audio, /HeaderSettingsButton \{[^]*?description: "Sound settings"[^]*?openSystemSettings\(popup.panel.screen, "audio"\)/);
  assert.doesNotMatch(audio, /settingsFooter/);
  assert.match(control, /HeaderSettingsButton \{[^]*?description: "System Settings"/);
  assert.doesNotMatch(control, /title: "System Settings"/);
  assert.match(control, /anchors.topMargin: header.y \+ header.height \+ 10/);
  assert.match(read('NotificationCenter.qml'), /openSystemSettings\(popup.panel.screen, "notifications"\)/);
});

test('connectivity header gear retains all settings destinations without radio changes', () => {
  const source = read('ConnectivityCenter.qml');
  assert.match(source, /HeaderSettingsButton \{[^]*?onOpening: popup.requestOpen\(true\)/);
  assert.match(source, /text: "Connectivity settings"[^\n]*openSystemSettings\(popup.panel.screen, "connectivity"\)/);
  assert.match(source, /text: "Bluetooth preferences"[^\n]*openSystemSettings\(popup.panel.screen, "connectivityPreferences"\)/);
  assert.match(source, /text: "Network settings"[^\n]*requestClose\(true\)[^\n]*nm-connection-editor/);
  assert.match(source, /text: "Bluetooth settings"[^\n]*requestClose\(true\)[^\n]*blueman-manager/);
  assert.doesNotMatch(source, /title: "(?:Network|Bluetooth) settings"/);
});
