const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');

const source = fs.readFileSync(path.join(__dirname, '../QuoteService.qml'), 'utf8');

function serviceForTest() {
  const service = { _snapshot: {}, _lastAttempt: 0, _process: { running: false }, loading: false, available: false, stale: true };
  service.clock = Date.now();
  const context = vm.createContext({ service, Date: class extends Date { static now() { return service.clock; } } });
  for (const name of ['refresh', '_accept']) {
    const match = source.match(new RegExp(`^( +)function ${name}\\([^]*?\\n\\1\\}`, 'm'));
    assert.ok(match, `missing ${name}`);
    service[name] = vm.runInContext(`(${match[0]})`, context);
  }
  return service;
}

test('quote service starts lazily, deduplicates requests, and validates snapshots', () => {
  const service = serviceForTest();
  service.refresh();
  assert.equal(service.loading, true);
  assert.equal(service._process.running, true);
  const attempt = service._lastAttempt;
  service.refresh(true);
  assert.equal(service._lastAttempt, attempt);

  service._accept(JSON.stringify({ available: true, date: '2026-09-16', quote: 'Keep going.', stale: false, error: '' }));
  assert.equal(service._snapshot.quote, 'Keep going.');
  assert.equal(service._failure, '');
  const previous = service._snapshot;
  service._accept('{bad');
  assert.equal(service._snapshot, previous);
  assert.equal(service._failure, 'Quote snapshot unavailable.');
});

test('quote service rejects unsafe or malformed quote data', () => {
  const service = serviceForTest();
  const valid = { available: true, date: '2026-09-16', quote: 'Keep going.', stale: false, error: '' };
  service._accept(JSON.stringify(valid));
  const previous = service._snapshot;
  for (const quote of ['<b>bad</b>', 'bad\nline']) {
    service._accept(JSON.stringify({ ...valid, quote }));
    assert.equal(service._snapshot, previous);
    assert.equal(service._failure, 'Quote snapshot unavailable.');
  }
});
