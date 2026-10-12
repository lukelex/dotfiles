const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const shell = fs.readFileSync(path.join(__dirname, '../shell.qml'), 'utf8');
const osd = fs.readFileSync(path.join(__dirname, '../SystemOsd.qml'), 'utf8');

test('successful reloads replace the built-in popup with the shared system OSD', () => {
  const calls = [];
  const handler = shell.match(/function onReloadCompleted\(\) \{([\s\S]*?)\n    \}/);
  assert.ok(handler);
  vm.runInNewContext(handler[1], {
    Quickshell: { inhibitReloadPopup: () => calls.push('inhibit') },
    notifications: { showOsd: (...args) => calls.push(args) },
  });
  assert.deepEqual(calls, ['inhibit', ['Reload', 0, 'refresh-cw', 'Quickshell Reloaded']]);
  assert.doesNotMatch(shell, /onReloadFailed/);
});

test('reload OSDs show an icon and label without a percentage meter', () => {
  const expression = osd.match(/readonly property bool labeledOsd: (.*)/)[1];
  for (const summary of ['Reload', 'Layout', 'Volume', 'Brightness', 'Microphone']) {
    assert.equal(vm.runInNewContext(expression, { displayedOsd: { summary } }),
      ['Reload', 'Layout'].includes(summary));
  }
  assert.equal(Boolean(vm.runInNewContext(expression, { displayedOsd: null })), false);
  assert.match(osd, /if \(popup\.labeledOsd\)\s+return popup\.displayedOsd\.osdIconName/);
  assert.match(osd, /visible: !popup\.labeledOsd/);
  assert.match(osd, /: popup\.labeledOsd\s+\? \(popup\.displayedOsd\.osdLabel/);
  assert.ok(fs.existsSync(path.join(__dirname, '../../lucide/svg/refresh-cw.svg')));
});
