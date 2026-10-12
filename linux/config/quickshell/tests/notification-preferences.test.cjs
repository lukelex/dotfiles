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
