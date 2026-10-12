const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');
const read = name => fs.readFileSync(path.resolve(__dirname, '..', name), 'utf8');

test('System Settings exposes Wi-Fi management and scans only while that page is shown', () => {
  const settings = read('SystemSettings.qml');
  const bar = read('Bar.qml');
  const service = read('ConnectivityService.qml');
  assert.match(settings, /key: "connectivity", label: "Connectivity"/);
  assert.doesNotMatch(settings, /key: "wifi", label: "Wi-Fi networks"/);
  assert.match(settings, /WifiSettings \{[^]*?visible: window\.section === "connectivity" && window\.connectivityTab === "networks"/);
  assert.match(settings, /wifiDiscoveryActive: visible && section === "connectivity" && connectivityTab === "networks"/);
  assert.match(bar, /readonly property bool wifiSettingsOpen: systemSettings.wifiDiscoveryActive/);
  assert.match(bar, /wifiDiscoveryEnabled: root.wifiSettingsOpen/);
  assert.match(settings, /property bool connectivityAdvanced: false/);
  assert.match(settings, /window.connectivityAdvanced && field.kind !== "boolean"/);
  assert.match(service, /service\.wifiScanningEnabled \|\| service\.wifiDiscoveryEnabled \|\| service\.wifiSuggestionsEnabled && service\.wifiWeak/);
  assert.match(service, /onTriggered: service\.wifiRescanSuspended = false/);
});

test('Wi-Fi hierarchy puts current and saved connections before discovery and collapsed unavailable profiles', () => {
  const ui = read('WifiSettings.qml');
  const service = read('ConnectivityService.qml');
  assert.match(ui, /text: "Other nearby networks"/);
  assert.match(ui, /entries: page\.service\.discoveredNetworks/);
  assert.match(ui, /text: "Saved networks"/);
  assert.match(ui, /entries: page\.availableSaved/);
  assert.match(ui, /service\.connectNetwork\(row\.network\)/);
  assert.match(ui, /property bool unavailableExpanded: false/);
  assert.match(ui, /visible: page\.unavailableExpanded && count > 0/);
  const positions = ['entries: page.currentNetworks', 'entries: page.availableSaved',
    'entries: page.service.discoveredNetworks', 'entries: page.unavailableSaved', 'text: "Add hidden network…"'].map(text => ui.indexOf(text));
  assert.ok(positions.every((position, i) => position >= 0 && (!i || position > positions[i - 1])));
  assert.match(service, /readonly property var knownNetworks: service\._networks\.filter\(network => network\.known\)/);
  assert.match(service, /service\.knownNetworks\.indexOf\(network\)/);
});

test('new personal networks use native credentials; credentials never enter shell commands or preferences', () => {
  const ui = read('WifiSettings.qml');
  const service = read('ConnectivityService.qml');
  assert.match(ui, /echoMode: TextInput\.Password/);
  assert.match(ui, /const secret = passphrase\.text[\s\S]*?passphrase\.clear\(\)[\s\S]*?connectDiscoveredNetwork\(row\.network, secret\)/);
  assert.match(service, /network\.connectWithPsk\(secured \? passphrase : ""\)/);
  assert.match(ui, /text: "Add hidden network…"[\s\S]*?nm-connection-editor/);
  assert.doesNotMatch(ui, /Process\s*\{|command:\s*\[[^\]]*passphrase/);
  assert.doesNotMatch(service, /execDetached\([^\n]*passphrase|preferences\.setValue\([^\n]*passphrase/);
});

test('forget is explicitly confirmed and cannot remove a connected or changing profile', () => {
  const ui = read('WifiSettings.qml');
  const service = read('ConnectivityService.qml');
  assert.match(ui, /Controls.MenuItem \{[^]*?text: "Forget network…"[^]*?onTriggered: row.confirmForget = true/);
  assert.match(ui, /visible: row.confirmForget/);
  assert.match(ui, /text: "Cancel"; quiet: true; onClicked: row.confirmForget = false/);
  assert.match(service, /!network\.known \|\| network\.connected\s*\|\| network\.stateChanging/);
  assert.match(service, /network\.forget\(\)/);
});

test('unsupported enterprise/certificate security is delegated instead of shown as a PSK password flow', () => {
  const ui = read('WifiSettings.qml');
  const service = read('ConnectivityService.qml');
  assert.match(service, /function wifiCanConnectDiscovered/);
  assert.match(ui, /wifiCanConnectDiscovered\(row\.details\) \? "Connect" : "Configure…"/);
  assert.match(ui, /if \(!page\.service\.wifiCanConnectDiscovered\(row\.network\)\)\s*Quickshell\.execDetached\(\["nm-connection-editor"\]\)/);
});

function loadFunction(name, context) {
  const match = read('WifiSettings.qml').match(new RegExp(`  function ${name}\\([^]*?\\n  \\}`));
  assert.ok(match, name);
  return vm.runInNewContext(`(${match[0]})`, context);
}

test('scan updates preserve row identities/order and typing while appending new networks', () => {
  const network = (name, strength) => ({ name, signalStrength: strength, security: 1, device: { name: 'wlan0' } });
  const a = network('A', 0.9), b = network('B', 0.4), c = network('C', 1);
  const page = {};
  page.networkKey = loadFunction('networkKey', {});
  const sync = loadFunction('syncRows', { page });
  const records = [];
  const model = {
    get count() { return records.length; }, get: i => records[i],
    remove: i => records.splice(i, 1), append: entry => records.push(entry),
    setProperty: (i, key, value) => { records[i][key] = value; },
  };
  sync(model, [a, b]);
  const original = records[1];
  original.passwordDraft = 'user is typing';
  b.signalStrength = 0.99;
  sync(model, [c, b, a]);
  assert.deepEqual(records.map(r => r.network.name), ['A', 'B', 'C']);
  assert.equal(records[1], original);
  assert.equal(records[1].passwordDraft, 'user is typing');
  const replacement = { ...b };
  sync(model, [replacement, c]);
  assert.equal(records[0], original);
  assert.equal(records[0].network, replacement);
  assert.equal(records.length, 2);
});

test('connection errors remain beside the target and password flow focuses, clears and guards Enter', () => {
  const ui = read('WifiSettings.qml');
  assert.match(ui, /visible: page.actionKey === row.identity && page.service.wifiError !== ""/);
  assert.match(ui, /page.service.wifiError !== "" && !page.errorHasRow/);
  assert.match(ui, /passphrase.forceActiveFocus\(\)/);
  assert.match(ui, /onAccepted: \{ if \(connectButton.enabled\) connectButton.clicked\(\) \}/);
  assert.match(ui, /onVisibleChanged: \{ if \(!visible\) passphrase.clear\(\) \}/);
  assert.match(ui, /columns: row.narrow \? 2 : 3/);
  assert.match(ui, /visible: page.multipleAdapters/);
  assert.doesNotMatch(ui, /Flickable|ScrollView/);
});
