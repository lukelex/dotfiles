const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');

function harness() {
  const source = fs.readFileSync(path.join(__dirname, '../BluetoothManager.qml'), 'utf8');
  const writes = [];
  const context = vm.createContext({
    active: true, ready: true, closing: false, scanning: false, seen: [], prompt: null,
    pendingPath: '', pendingAction: '', resultPath: '', error: '', message: '', scanError: '',
    serial: 0, pendingId: 0, scanId: 0,
    process: { running: true, write: value => writes.push(JSON.parse(value)) },
    startup: { stop() {}, restart() {} }, shutdown: { stop() {}, restart() {} },
  });
  context.manager = context;
  for (const name of ['send', 'run', 'scan', 'answer', 'accept', 'start']) {
    const match = source.match(new RegExp(`  function ${name}\\([^]*?\\n  \\}`));
    assert.ok(match, name);
    vm.runInContext(match[0], context);
  }
  const activeChanged = source.match(/  onActiveChanged: \{([^]*?)\n  \}/)[1];
  return { context, writes, activeChanged: () => vm.runInContext(activeChanged, context) };
}

test('device actions retain captured identity and reject duplicates until the matching result', () => {
  const { context: c, writes } = harness();
  c.run('connect', '/device/a');
  c.run('forget', '/device/b');
  assert.equal(writes.length, 1);
  c.accept(JSON.stringify({ event: 'result', id: 99, path: '/device/b', error: 'stale' }));
  assert.equal(c.pendingPath, '/device/a');
  c.accept(JSON.stringify({ event: 'result', id: 1, path: '/device/a', error: 'Unavailable' }));
  assert.equal(c.pendingPath, '');
  assert.equal(c.resultPath, '/device/a');
  assert.equal(c.error, 'Unavailable');
});

test('closing cancels through stdin, clears prompts and ignores late helper events', () => {
  const { context: c, writes, activeChanged } = harness();
  c.prompt = { token: 42, kind: 'RequestPinCode' };
  c.active = false;
  activeChanged();
  assert.equal(writes.at(-1).action, 'shutdown');
  assert.equal(c.prompt, null);
  assert.equal(c.ready, false);
  c.accept(JSON.stringify({ event: 'ready' }));
  c.accept(JSON.stringify({ event: 'prompt', prompt: { token: 43 } }));
  assert.equal(c.ready, false);
  assert.equal(c.prompt, null);
});

test('pairing answers are bound to their prompt and sent once without retained input', () => {
  const { context: c, writes } = harness();
  c.prompt = { token: 3 };
  c.answer(2, true, '123456');
  assert.equal(writes.length, 0);
  c.answer(3, true, '123456');
  assert.deepEqual(writes[0], { action: 'reply', token: 3, accept: true, value: '123456' });
  assert.equal(c.prompt, null);
  c.answer(3, true, '123456');
  assert.equal(writes.length, 1);
});

test('partial adapter discovery failures do not stop successful adapters or erase results', () => {
  const { context: c } = harness();
  c.scan();
  c.accept(JSON.stringify({ event: 'result', id: c.scanId, error: 'hci1 blocked' }));
  assert.equal(c.scanning, true);
  c.accept(JSON.stringify({ event: 'scan', active: false, seen: ['/device/a'] }));
  assert.equal(c.scanning, false);
  assert.deepEqual(Array.from(c.seen), ['/device/a']);
  assert.equal(c.scanError, 'hci1 blocked');
});
