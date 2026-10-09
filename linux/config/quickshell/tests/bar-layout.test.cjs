const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { test } = require('node:test');
const vm = require('node:vm');

const source = fs.readFileSync(path.join(__dirname, '../Bar.qml'), 'utf8');

function setup() {
  const root = {
    hyprlandSession: false,
    hyprlandLayout: '',
    layoutRevision: 0,
    hyprlandLayoutInitialized: false,
    i3Layout: '',
    i3LayoutRevision: 0,
    resizeMode: false,
    resizeModeRevision: 0,
    hyprlandModeInitialized: false,
    layoutOsdArmed: false,
    lastLayoutOsdLayout: '',
    i3LayoutFocusId: '',
  };
  const hyprlandLayout = { revision: 0, running: false };
  const i3LayoutQuery = { revision: 0, running: false };
  const Hyprland = { focusedMonitor: null };
  const warnings = [];
  const osdCalls = [];
  const context = vm.createContext({
    root,
    hyprlandLayout,
    i3LayoutQuery,
    Hyprland,
    console: { warn: (...args) => warnings.push(args) },
  });
  for (const name of [
    'handleHyprlandEvent', 'refreshHyprlandLayout', 'applyHyprlandLayout', 'layoutIconFor',
    'refreshI3Layout', 'applyI3Layout', 'i3FocusedNode', 'i3LayoutFromTree',
    'layoutDisplayName', 'armLayoutOsd', 'maybeShowLayoutOsd',
    'handleI3BindingEvent', 'layoutFromBindingCommand',
  ]) {
    const match = source.match(new RegExp(`  function ${name}\\([^]*?\\n  \\}`));
    assert.ok(match, `Missing ${name}`);
    root[name] = vm.runInContext(`(${match[0]})`, context);
  }
  root.refreshHyprlandSubmap = () => {};
  root.notificationService = {
    showOsd: (...args) => osdCalls.push(args),
  };
  return { root, hyprlandLayout, i3LayoutQuery, Hyprland, warnings, osdCalls };
}

test('layout icons cover every supported Hyprland and i3 layout', () => {
  const { root } = setup();
  const expected = {
    dwindle: 'columns-2',
    master: 'layout-panel-left',
    monocle: 'maximize',
    scrolling: 'gallery-horizontal-end',
    splith: 'columns-2',
    splitv: 'rows-2',
    tabbed: 'layout-panel-top',
    stacked: 'layout-list',
  };
  for (const [layout, icon] of Object.entries(expected))
    assert.equal(root.layoutIconFor(layout), icon);
});

test('unknown layouts resolve to no icon', () => {
  const { root } = setup();
  for (const layout of ['', 'unknown', 'dockarea', 'output', 'default', 'hyprsplit'])
    assert.equal(root.layoutIconFor(layout), '');
});

test('Hyprland layout skips the query until IPC initialization provides a focused monitor', () => {
  const { root, hyprlandLayout, Hyprland } = setup();
  root.hyprlandSession = true;
  root.refreshHyprlandLayout();
  assert.equal(hyprlandLayout.running, false);
  Hyprland.focusedMonitor = { name: 'DP-1' };
  root.refreshHyprlandLayout();
  assert.equal(hyprlandLayout.running, true);
  assert.equal(hyprlandLayout.revision, root.layoutRevision);
});

test('duplicate Hyprland layout queries are ignored while one is in flight', () => {
  const { root, hyprlandLayout, Hyprland } = setup();
  root.hyprlandSession = true;
  Hyprland.focusedMonitor = { name: 'DP-1' };
  root.refreshHyprlandLayout();
  root.refreshHyprlandLayout();
  assert.equal(hyprlandLayout.running, true);
  assert.equal(hyprlandLayout.revision, 1);
});

test('Hyprland layout is parsed from the getoption string', () => {
  const { root, hyprlandLayout, Hyprland } = setup();
  root.hyprlandSession = true;
  Hyprland.focusedMonitor = { name: 'DP-1' };
  root.refreshHyprlandLayout();
  root.applyHyprlandLayout('{"option":"general:layout","int":0,"float":0,"str":"master","data":{}}', hyprlandLayout.revision);
  assert.equal(root.hyprlandLayout, 'master');
  assert.equal(root.hyprlandLayoutInitialized, true);
});

test('Hyprland config reload and the bar IPC handler re-query the current layout', () => {
  const { root, hyprlandLayout, Hyprland } = setup();
  root.hyprlandSession = true;
  Hyprland.focusedMonitor = { name: 'DP-1' };
  root.handleHyprlandEvent({ name: 'configreloaded', data: '' });
  assert.equal(hyprlandLayout.running, true);
  assert.equal(hyprlandLayout.revision, 1);
  root.applyHyprlandLayout('{"str":"dwindle"}', hyprlandLayout.revision);
  root.handleHyprlandEvent({ name: 'configreloaded', data: '' });
  assert.equal(hyprlandLayout.running, true);
  assert.equal(hyprlandLayout.revision, 1);
  assert.match(source, /function refreshLayout\(\) \{\n\s+root\.refreshHyprlandLayout\(\)\n\s+root\.refreshI3Layout\(\)\n\s+\}/);
});

test('a stale layout query cannot overwrite a newer one', () => {
  const { root, hyprlandLayout, Hyprland } = setup();
  root.hyprlandSession = true;
  Hyprland.focusedMonitor = { name: 'DP-1' };
  root.refreshHyprlandLayout();
  const staleRevision = hyprlandLayout.revision;
  hyprlandLayout.running = false;
  root.refreshHyprlandLayout();
  root.applyHyprlandLayout('{"str":"monocle"}', staleRevision);
  assert.equal(root.hyprlandLayout, '');
  root.applyHyprlandLayout('{"str":"scrolling"}', hyprlandLayout.revision);
  assert.equal(root.hyprlandLayout, 'scrolling');
});

test('invalid responses keep the known layout and warn for unparsable payloads', () => {
  const { root, hyprlandLayout, warnings } = setup();
  root.hyprlandSession = true;
  root.hyprlandLayout = 'master';
  for (const data of ['unknown request', 'null'])
    root.applyHyprlandLayout(data, hyprlandLayout.revision);
  assert.equal(root.hyprlandLayout, 'master');
  assert.equal(root.hyprlandLayoutInitialized, false);
  assert.equal(warnings.length, 2);
});

test('non-string layout responses are ignored without warning', () => {
  const { root, hyprlandLayout, warnings } = setup();
  root.hyprlandSession = true;
  root.hyprlandLayout = 'master';
  for (const data of ['{}', '{"str":42}', '{"str":null}', '[]'])
    root.applyHyprlandLayout(data, hyprlandLayout.revision);
  assert.equal(root.hyprlandLayout, 'master');
  assert.equal(root.hyprlandLayoutInitialized, false);
  assert.equal(warnings.length, 0);
});

test('i3 sessions never run Hyprland layout queries', () => {
  const { root, hyprlandLayout, Hyprland } = setup();
  root.hyprlandSession = false;
  Hyprland.focusedMonitor = { name: 'DP-1' };
  root.refreshHyprlandLayout();
  assert.equal(hyprlandLayout.running, false);
  root.applyHyprlandLayout('{"str":"master"}', 0);
  assert.equal(root.hyprlandLayout, '');
});

test('layout plumbing uses the general:layout option query', () => {
  assert.match(source, /command: \["hyprctl", "-j", "getoption", "general:layout"\]/);
  assert.match(source, /onStreamFinished: root\.applyHyprlandLayout\(text, hyprlandLayout\.revision\)/);
});

function treeWith(focusedNode, workspace) {
  return {
    type: 'root', focused: false, nodes: [{
      type: 'output', focused: false, nodes: [{
        type: 'con', focused: false, nodes: [workspace],
      }],
    }],
  };
}

test('i3 split container under the workspace reports its own layout, not the workspace node', () => {
  const { root } = setup();
  const tree = treeWith({ type: 'con', name: 'window', focused: true, layout: 'splith', nodes: [] }, {
    type: 'workspace', name: '6', focused: false, layout: 'splith', nodes: [{
      type: 'con', name: null, focused: false, layout: 'splitv', nodes: [
        { type: 'con', name: 'window', focused: true, layout: 'splith', nodes: [] },
      ],
    }],
  });
  assert.equal(root.i3LayoutFromTree(JSON.stringify(tree)), 'splitv');
});

test('i3 window directly under a workspace uses that workspace layout', () => {
  const { root } = setup();
  const tree = treeWith({ type: 'con', name: 'window', focused: true, layout: 'splith', nodes: [] }, {
    type: 'workspace', name: '1', focused: false, layout: 'splith', nodes: [
      { type: 'con', name: 'window', focused: true, layout: 'splith', nodes: [] },
    ],
  });
  assert.equal(root.i3LayoutFromTree(JSON.stringify(tree)), 'splith');
});

test('an empty focused i3 workspace uses its own layout', () => {
  const { root } = setup();
  const tree = treeWith(null, { type: 'workspace', name: '3', focused: true, layout: 'tabbed', nodes: [] });
  assert.equal(root.i3LayoutFromTree(JSON.stringify(tree)), 'tabbed');
});

test('an i3 tree without a focused node yields no layout', () => {
  const { root } = setup();
  const tree = treeWith(null, { type: 'workspace', name: '1', focused: false, layout: 'splith', nodes: [] });
  assert.equal(root.i3LayoutFromTree(JSON.stringify(tree)), '');
});

test('i3 layout queries skip Hyprland sessions and deduplicate while running', () => {
  const { root, i3LayoutQuery } = setup();
  root.hyprlandSession = true;
  root.refreshI3Layout();
  assert.equal(i3LayoutQuery.running, false);
  root.hyprlandSession = false;
  root.refreshI3Layout();
  root.refreshI3Layout();
  assert.equal(i3LayoutQuery.running, true);
  assert.equal(i3LayoutQuery.revision, 1);
});

test('i3 layout is parsed from the get_tree payload', () => {
  const { root, i3LayoutQuery } = setup();
  const tree = treeWith({ type: 'con', name: 'window', focused: true, layout: 'splith', nodes: [] }, {
    type: 'workspace', name: '6', focused: false, layout: 'splith', nodes: [{
      type: 'con', name: null, focused: false, layout: 'stacked', nodes: [
        { type: 'con', name: 'window', focused: true, layout: 'splith', nodes: [] },
      ],
    }],
  });
  root.refreshI3Layout();
  root.applyI3Layout(JSON.stringify(tree), i3LayoutQuery.revision);
  assert.equal(root.i3Layout, 'stacked');
});

test('a stale i3 layout response cannot overwrite a newer one', () => {
  const { root, i3LayoutQuery, warnings } = setup();
  const tree = JSON.stringify(treeWith(
    { type: 'con', name: 'window', focused: true, layout: 'splith', nodes: [] },
    { type: 'workspace', name: '6', focused: false, layout: 'splith', nodes: [{
      type: 'con', name: null, focused: false, layout: 'tabbed', nodes: [
        { type: 'con', name: 'window', focused: true, layout: 'splith', nodes: [] },
      ],
    }] },
  ));
  root.refreshI3Layout();
  const staleRevision = i3LayoutQuery.revision;
  i3LayoutQuery.running = false;
  root.refreshI3Layout();
  root.applyI3Layout(tree, staleRevision);
  assert.equal(root.i3Layout, '');
  root.applyI3Layout(tree, i3LayoutQuery.revision);
  assert.equal(root.i3Layout, 'tabbed');
  assert.equal(warnings.length, 0);
});

test('a malformed i3 tree warns and keeps the known layout', () => {
  const { root, warnings } = setup();
  root.i3Layout = 'splitv';
  root.applyI3Layout('unknown request', 0);
  assert.equal(root.i3Layout, 'splitv');
  assert.equal(warnings.length, 1);
});

test('i3 keeps the user\'s own layout binds and adds no cycle binding or poke', () => {
  const bindings = fs.readFileSync(path.join(__dirname, '../..', 'i3', 'bindings.conf'), 'utf8');
  assert.match(bindings, /bindsym \$mod\+s layout stacking/);
  assert.match(bindings, /bindsym \$mod\+w layout tabbed/);
  assert.match(bindings, /bindsym \$mod\+e layout toggle split/);
  assert.match(bindings, /bindsym \$mod\+t split toggle/);
  assert.doesNotMatch(bindings, /layout toggle all/);
  assert.doesNotMatch(bindings, /refreshLayout/);
});

test('i3 layout sync uses a quiet get_tree poll instead of poked binds', () => {
  assert.match(
    source,
    /Timer \{\n\s+id: i3LayoutPoll\n\s+interval: 1000\n\s+repeat: true\n\s+running: !root\.hyprlandSession\n\s+onTriggered: root\.refreshI3Layout\(\)\n\s+\}/,
  );
});

test('the Hyprland cycle layout script pokes the bar after setting the layout', () => {
  const script = fs.readFileSync(path.join(__dirname, '../../..', 'scripts', 'hypr-cycle-layout'), 'utf8');
  assert.match(
    script,
    /qs ipc --path "\$HOME\/dotfiles\/linux\/config\/quickshell\/shell\.qml" call bar refreshLayout[^\n]*\|\| true/,
  );
});

test('the Hyprland master/dwindle binds poke the bar after setting the layout', () => {
  const binds = fs.readFileSync(path.join(__dirname, '../../hypr/keybindings.lua'), 'utf8');
  assert.match(binds, /SHIFT \+ M[\s\S]*?general:layout master[\s\S]*?call bar refreshLayout/);
  assert.match(binds, /SHIFT \+ D[\s\S]*?general:layout dwindle[\s\S]*?call bar refreshLayout/);
});

test('an i3 layout keybinding flashes the OSD immediately from the binding event', () => {
  const { root, osdCalls, i3LayoutQuery } = setup();
  root.i3Layout = 'splith';
  root.maybeShowLayoutOsd('splith'); // arm the OSD
  root.handleI3BindingEvent({ type: 'binding', data: JSON.stringify({ change: 'run', binding: { command: 'layout stacking' } }) });
  assert.deepEqual(osdCalls, [['Layout', 0, 'layout-list', 'Stacked']]);
  assert.equal(i3LayoutQuery.running, true); // the confirmation poll is pulled early too
});

test('layout binds predict their result regardless of the current layout', () => {
  const { root } = setup();
  assert.equal(root.layoutFromBindingCommand('layout stacking'), 'stacked');
  assert.equal(root.layoutFromBindingCommand('layout tabbed'), 'tabbed');
  assert.equal(root.layoutFromBindingCommand('  layout tabbed  '), 'tabbed');
  assert.equal(root.layoutFromBindingCommand('layout stacking, focus parent'), 'stacked');
  assert.equal(root.layoutFromBindingCommand(''), '');
});

test('toggle-split binds predict the flipped split only from a current split', () => {
  const { root } = setup();
  for (const [current, flipped] of [['splith', 'splitv'], ['splitv', 'splith']]) {
    root.i3Layout = current;
    assert.equal(root.layoutFromBindingCommand('layout toggle split'), flipped);
    assert.equal(root.layoutFromBindingCommand('split toggle'), flipped);
    assert.equal(root.layoutFromBindingCommand('split toggle, focus parent'), flipped);
  }
  root.i3Layout = 'tabbed';
  assert.equal(root.layoutFromBindingCommand('layout toggle split'), '');
  assert.equal(root.layoutFromBindingCommand('split toggle'), '');
});

test('non-layout keybindings never flash the layout OSD or poke the poll', () => {
  const { root, osdCalls, i3LayoutQuery } = setup();
  root.i3Layout = 'splith';
  root.maybeShowLayoutOsd('splith');
  root.handleI3BindingEvent({ type: 'binding', data: JSON.stringify({ change: 'run', binding: { command: 'workspace next' } }) });
  root.handleI3BindingEvent({ type: 'binding', data: JSON.stringify({ change: 'run', binding: { command: 'fullscreen toggle' } }) });
  root.handleI3BindingEvent({ type: 'binding', data: JSON.stringify({ change: 'release', binding: { command: 'layout stacking' } }) });
  root.handleI3BindingEvent({ type: 'binding', data: 'invalid' });
  assert.equal(osdCalls.length, 0);
  assert.equal(i3LayoutQuery.running, false);
});

test('i3 binding events and their predictions never affect Hyprland sessions', () => {
  const { root, osdCalls } = setup();
  root.hyprlandSession = true;
  root.handleI3BindingEvent({ type: 'binding', data: JSON.stringify({ change: 'run', binding: { command: 'layout stacking' } }) });
  assert.equal(osdCalls.length, 0);
  // prediction is a pure command mapping, still available for i3 sessions
  assert.equal(root.layoutFromBindingCommand('layout stacking'), 'stacked');
});

test('layout display names cover every supported Hyprland and i3 layout', () => {
  const { root } = setup();
  const expected = {
    dwindle: 'Dwindle', master: 'Master', monocle: 'Monocle', scrolling: 'Scrolling',
    splith: 'Split horizontal', splitv: 'Split vertical', tabbed: 'Tabbed', stacked: 'Stacked',
  };
  for (const [layout, label] of Object.entries(expected))
    assert.equal(root.layoutDisplayName(layout), label);
  assert.equal(root.layoutDisplayName(''), '');
});

test('the layout OSD arms on the first resolved layout without showing it', () => {
  const { root, osdCalls } = setup();
  root.hyprlandSession = true;
  root.applyHyprlandLayout('{"str":"dwindle"}', 0);
  assert.equal(root.layoutOsdArmed, true);
  assert.equal(osdCalls.length, 0);
});

test('Hyprland OSD shows the new layout icon and name once, and not again for the same value', () => {
  const { root, osdCalls } = setup();
  root.hyprlandSession = true;
  root.applyHyprlandLayout('{"str":"dwindle"}', 0);
  assert.equal(osdCalls.length, 0);
  root.applyHyprlandLayout('{"str":"master"}', 0);
  assert.deepEqual(osdCalls, [['Layout', 0, 'layout-panel-left', 'Master']]);
  // config reload re-querying the same value must not re-flash the OSD
  root.applyHyprlandLayout('{"str":"master"}', 0);
  assert.equal(osdCalls.length, 1);
});

test('the layout OSD does not arm or fire on unknown or icon-less layouts', () => {
  const { root, osdCalls } = setup();
  for (const layout of ['', 'unknown', 'dockarea'])
    root.maybeShowLayoutOsd(layout);
  assert.equal(root.layoutOsdArmed, false);
  assert.equal(osdCalls.length, 0);
  root.maybeShowLayoutOsd('splitv');
  assert.equal(root.layoutOsdArmed, true);
  assert.equal(osdCalls.length, 0);
});

test('i3 OSD ignores layout differences caused by moving focus between windows or workspaces', () => {
  const { root, osdCalls, i3LayoutQuery } = setup();
  root.refreshI3Layout();
  // first resolution arms the OSD, silently
  root.applyI3Layout(JSON.stringify(treeWith(null, {
    type: 'workspace', name: '6', focused: false, layout: 'splith', nodes: [
      { type: 'con', id: 11, name: 'window', focused: true, layout: 'splith', nodes: [] },
    ],
  })), i3LayoutQuery.revision);
  assert.equal(root.i3Layout, 'splith');
  assert.equal(root.layoutOsdArmed, true);
  assert.equal(osdCalls.length, 0);
  // focus moves into a tabbed container: the shown layout changes, no OSD
  root.applyI3Layout(JSON.stringify(treeWith(null, {
    type: 'workspace', name: '6', focused: false, layout: 'splith', nodes: [{
      type: 'con', id: null, name: null, focused: false, layout: 'tabbed', nodes: [
        { type: 'con', id: 22, name: 'window2', focused: true, layout: 'splith', nodes: [] },
      ],
    }],
  })), i3LayoutQuery.revision);
  assert.equal(root.i3Layout, 'tabbed');
  assert.equal(osdCalls.length, 0);
});

test('i3 OSD fires when the layout changes while the focused node is unchanged', () => {
  const { root, osdCalls, i3LayoutQuery } = setup();
  const window = { type: 'con', id: 11, name: 'window', focused: true, layout: 'splith', nodes: [] };
  root.refreshI3Layout();
  const tree = layout => JSON.stringify(treeWith(null, {
    type: 'workspace', name: '6', focused: false, layout: 'splith', nodes: [{
      type: 'con', id: null, name: null, focused: false, layout, nodes: [window],
    }],
  }));
  root.applyI3Layout(tree('splith'), i3LayoutQuery.revision);
  assert.equal(osdCalls.length, 0);
  root.applyI3Layout(tree('stacked'), i3LayoutQuery.revision);
  assert.equal(root.i3Layout, 'stacked');
  assert.deepEqual(osdCalls, [['Layout', 0, 'layout-list', 'Stacked']]);
  // re-arming the same layout (i3 wrap container appears) must not re-flash
  root.applyI3Layout(tree('stacked'), i3LayoutQuery.revision);
  assert.equal(osdCalls.length, 1);
});

test('SystemOsd renders Layout OSDs with the supplied icon and label instead of a meter', () => {
  const systemOsd = fs.readFileSync(path.join(__dirname, '../SystemOsd.qml'), 'utf8');
  assert.match(systemOsd, /summary === "Layout"[\s\S]*?osdIconName/);
  assert.match(systemOsd, /summary !== "Layout"/);
  assert.match(systemOsd, /osdLabel \|\| ""/);
});

test('NotificationService records the OSD icon name and label', () => {
  const service = fs.readFileSync(path.join(__dirname, '../NotificationService.qml'), 'utf8');
  assert.match(service, /function showOsd\(summary, value, iconName, label\)/);
  assert.match(service, /osdIconName: iconName,/);
  assert.match(service, /osdLabel: label \|\| "",/);
});