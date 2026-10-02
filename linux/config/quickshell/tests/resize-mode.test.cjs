const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { test } = require('node:test');
const vm = require('node:vm');

const source = fs.readFileSync(path.join(__dirname, '../Bar.qml'), 'utf8');

function setup() {
  const root = { hyprlandSession: false, resizeMode: false, resizeModeRevision: 0, hyprlandModeInitialized: false };
  const i3BindingState = { revision: 0, running: false };
  const hyprlandSubmap = { revision: 0, running: false };
  const Hyprland = { focusedMonitor: null, refreshMonitors() { this.refreshCount = (this.refreshCount || 0) + 1; } };
  const warnings = [];
  const context = vm.createContext({ root, i3BindingState, hyprlandSubmap, Hyprland, console: { warn: (...args) => warnings.push(args) } });
  for (const name of ['handleI3ModeEvent', 'applyI3BindingState', 'refreshHyprlandSubmap', 'handleHyprlandEvent', 'applyHyprlandSubmap']) {
    const match = source.match(new RegExp(`  function ${name}\\([^]*?\\n  \\}`));
    assert.ok(match, `Missing ${name}`);
    root[name] = vm.runInContext(`(${match[0]})`, context);
  }
  return { root, i3BindingState, hyprlandSubmap, Hyprland, warnings };
}

test('i3 mode events show Resize only in resize mode', () => {
  const { root } = setup();
  for (const [mode, visible] of [['resize', true], ['default', false], ['resize', true], ['other', false]]) {
    root.handleI3ModeEvent({ type: 'mode', data: JSON.stringify({ change: mode }) });
    assert.equal(root.resizeMode, visible);
  }
  assert.equal(root.resizeModeRevision, 4);
});

test('subscription queries the current i3 mode on startup or reconnect without polling', () => {
  const { root, i3BindingState } = setup();
  root.handleI3ModeEvent({ type: 'subscribe', data: '{"success":true}' });
  assert.equal(i3BindingState.running, true);
  root.applyI3BindingState('{"name":"resize"}', i3BindingState.revision);
  assert.equal(root.resizeMode, true);
  i3BindingState.running = false;
  root.handleI3ModeEvent({ type: 'subscribe', data: '{"success":true}' });
  root.applyI3BindingState('{"name":"default"}', i3BindingState.revision);
  assert.equal(root.resizeMode, false);
  assert.match(source, /command: \["i3-msg", "-t", "get_binding_state"\]/);
  assert.match(source, /onStreamFinished: root\.applyI3BindingState\(text, i3BindingState\.revision\)/);
});

test('a late startup query cannot overwrite a newer i3 mode event', () => {
  const { root, i3BindingState } = setup();
  root.handleI3ModeEvent({ type: 'subscribe', data: '{"success":true}' });
  root.handleI3ModeEvent({ type: 'mode', data: '{"change":"resize"}' });
  root.applyI3BindingState('{"name":"default"}', i3BindingState.revision);
  assert.equal(root.resizeMode, true);
});

test('unrelated or malformed events do not change the current resize mode', () => {
  const { root, i3BindingState, warnings } = setup();
  root.resizeMode = true;
  root.handleI3ModeEvent({ type: 'workspace', data: '{"change":"focus"}' });
  root.handleI3ModeEvent({ type: 'mode', data: 'invalid' });
  root.handleI3ModeEvent({ type: 'mode', data: '{}' });
  root.applyI3BindingState('invalid', 0);
  root.applyI3BindingState('{}', 0);
  assert.equal(root.resizeMode, true);
  assert.equal(root.resizeModeRevision, 0);
  assert.equal(i3BindingState.running, false);
  assert.equal(warnings.length, 2);
});

test('i3 events and binding-state queries do not affect Hyprland sessions', () => {
  const { root, i3BindingState } = setup();
  root.hyprlandSession = true;
  root.handleI3ModeEvent({ type: 'subscribe', data: '{"success":true}' });
  root.handleI3ModeEvent({ type: 'mode', data: '{"change":"resize"}' });
  root.applyI3BindingState('{"name":"resize"}', 0);
  assert.equal(root.resizeMode, false);
  assert.equal(i3BindingState.running, false);
});

test('Hyprland submap events show Resize on entry and hide it on reset or another submap', () => {
  const { root } = setup();
  root.hyprlandSession = true;
  for (const [mode, visible] of [['resize', true], ['', false], ['resize', true], ['reset', false], ['other', false]]) {
    root.handleHyprlandEvent({ name: 'submap', data: mode });
    assert.equal(root.resizeMode, visible);
  }
  assert.equal(root.resizeModeRevision, 5);
  assert.equal(root.hyprlandModeInitialized, true);
  root.handleHyprlandEvent({ name: 'workspacev2', data: '1,1' });
  assert.equal(root.resizeModeRevision, 5);
});

test('Hyprland waits for native initialization and restores an already active resize submap', () => {
  const { root, hyprlandSubmap, Hyprland } = setup();
  root.hyprlandSession = true;
  root.refreshHyprlandSubmap();
  assert.equal(hyprlandSubmap.running, false);
  Hyprland.focusedMonitor = { name: 'DP-1' };
  root.refreshHyprlandSubmap();
  assert.equal(hyprlandSubmap.running, true);
  root.applyHyprlandSubmap('"resize"\n', hyprlandSubmap.revision);
  assert.equal(root.resizeMode, true);
  assert.equal(root.hyprlandModeInitialized, true);
  assert.match(source, /command: \["hyprctl", "-j", "submap"\]/);
  assert.match(source, /onStreamFinished: root\.applyHyprlandSubmap\(text, hyprlandSubmap\.revision\)/);
  assert.match(source, /function onFocusedMonitorChanged\(\) \{\s+if \(!root\.hyprlandModeInitialized\)\s+root\.refreshHyprlandSubmap\(\)/);
  assert.match(source, /Component\.onCompleted: \{\s+root\.refreshHyprlandSubmap\(\)/);
});

test('Hyprland config reload queries current state and duplicate queries are ignored', () => {
  const { root, hyprlandSubmap, Hyprland } = setup();
  root.hyprlandSession = true;
  Hyprland.focusedMonitor = { name: 'DP-1' };
  root.handleHyprlandEvent({ name: 'submap', data: 'resize' });
  root.handleHyprlandEvent({ name: 'configreloaded', data: '' });
  assert.equal(hyprlandSubmap.running, true);
  assert.equal(hyprlandSubmap.revision, 1);
  root.handleHyprlandEvent({ name: 'submap', data: '' });
  root.refreshHyprlandSubmap();
  assert.equal(hyprlandSubmap.revision, 1);
  root.applyHyprlandSubmap('"resize"', hyprlandSubmap.revision);
  assert.equal(root.resizeMode, false);
  hyprlandSubmap.running = false;
  root.handleHyprlandEvent({ name: 'configreloaded', data: '' });
  root.applyHyprlandSubmap('"default"', hyprlandSubmap.revision);
  assert.equal(root.resizeMode, false);
});

test('Hyprland submap queries cannot overwrite newer entry or exit events', () => {
  for (const [mode, query, expected] of [['resize', '"default"', true], ['', '"resize"', false]]) {
    const { root, Hyprland, hyprlandSubmap } = setup();
    root.hyprlandSession = true;
    Hyprland.focusedMonitor = { name: 'DP-1' };
    root.refreshHyprlandSubmap();
    root.handleHyprlandEvent({ name: 'submap', data: mode });
    root.applyHyprlandSubmap(query, hyprlandSubmap.revision);
    assert.equal(root.resizeMode, expected);
  }
});

test('invalid Hyprland submap responses preserve known mode and special-workspace events still refresh monitors', () => {
  const { root, warnings, Hyprland } = setup();
  root.hyprlandSession = true;
  root.resizeMode = true;
  for (const data of ['unknown request', '{}', 'null', '42'])
    root.applyHyprlandSubmap(data, 0);
  assert.equal(root.resizeMode, true);
  assert.equal(root.hyprlandModeInitialized, false);
  assert.equal(warnings.length, 1);
  for (const name of ['activespecial', 'activespecialv2'])
    root.handleHyprlandEvent({ name, data: '' });
  assert.equal(Hyprland.refreshCount, 2);
});

test('Hyprland mode events and queries do not affect i3 sessions', () => {
  const { root, Hyprland, hyprlandSubmap } = setup();
  Hyprland.focusedMonitor = { name: 'DP-1' };
  root.resizeMode = true;
  root.refreshHyprlandSubmap();
  root.handleHyprlandEvent({ name: 'submap', data: '' });
  root.handleHyprlandEvent({ name: 'configreloaded', data: '' });
  root.applyHyprlandSubmap('"default"', 0);
  assert.equal(root.resizeMode, true);
  assert.equal(hyprlandSubmap.running, false);
  assert.equal(root.resizeModeRevision, 0);
});

test('Hyprland resize bindings match i3 navigation and exit keys', () => {
  const bindings = fs.readFileSync(path.join(__dirname, '../../hypr/keybindings.lua'), 'utf8');
  const submap = bindings.match(/hl\.define_submap\("resize", function\(\)[^]*?\nend\)/);
  assert.ok(submap);
  assert.match(bindings, /hl\.bind\(SUPER \.\. " \+ r", hl\.dsp\.submap\("resize"\)\)/);
  for (const [key, x, y] of [
    ['h', -50, 0], ['j', 0, 15], ['k', 0, -15], ['l', 50, 0],
    ['left', -50, 0], ['down', 0, 15], ['up', 0, -15], ['right', 50, 0],
  ]) {
    assert.ok(submap[0].includes(`hl.bind("${key}", hl.dsp.window.resize({ x = ${x}, y = ${y}, relative = true }), { repeating = true })`));
  }
  for (const key of ['escape', 'RETURN'])
    assert.ok(submap[0].includes(`hl.bind("${key}", hl.dsp.submap("reset"))`));
});
