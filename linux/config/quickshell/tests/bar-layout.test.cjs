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
  };
  const hyprlandLayout = { revision: 0, running: false };
  const i3LayoutQuery = { revision: 0, running: false };
  const Hyprland = { focusedMonitor: null };
  const warnings = [];
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
  ]) {
    const match = source.match(new RegExp(`  function ${name}\\([^]*?\\n  \\}`));
    assert.ok(match, `Missing ${name}`);
    root[name] = vm.runInContext(`(${match[0]})`, context);
  }
  root.refreshHyprlandSubmap = () => {};
  return { root, hyprlandLayout, i3LayoutQuery, Hyprland, warnings };
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