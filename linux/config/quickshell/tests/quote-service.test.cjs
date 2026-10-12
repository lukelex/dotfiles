const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');

process.env.TZ = 'America/New_York';

const source = fs.readFileSync(path.join(__dirname, '../QuoteService.qml'), 'utf8');

function serviceForTest() {
  const service = { _snapshot: {}, _lastAttempt: 0, _process: { running: false }, loading: false, available: false, stale: true };
  service.clock = Date.now();
  Object.defineProperty(service, 'available', { get: () => !!service._snapshot.quote });
  const context = vm.createContext({ service, Date: class extends Date { static now() { return service.clock; } },
    Qt: { formatDate: date => `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}` } });
  for (const name of ['refresh', '_accept', '_refreshDelay']) {
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

  service._accept('Keep going.\n');
  assert.equal(service._snapshot.quote, 'Keep going.');
  assert.equal(service._failure, '');
  const previous = service._snapshot;
  service._accept('');
  assert.equal(service._snapshot, previous);
  assert.equal(service._failure, 'Quote snapshot unavailable.');
});

test('quotes use local dates and refresh once when the local day changes', () => {
  const service = serviceForTest();
  service.clock = Date.parse('2026-10-09T23:59:00-04:00');
  service.refresh();
  service._accept('Today.');
  assert.equal(service._snapshot.date, '2026-10-09', 'not the next UTC date');
  assert.equal(service._refreshDelay(), 60000);
  service._process.running = false;
  service.refresh();
  assert.equal(service._process.running, false, 'same-day quote is reused');
  service.clock += 60000;
  service.refresh();
  assert.equal(service.loading, true);
  service._accept('Tomorrow.');
  assert.equal(service._snapshot.date, '2026-10-10');
  assert.equal(service._refreshDelay(), 24 * 60 * 60 * 1000);
});

test('midnight scheduling respects DST and failed rollover retries respect cooldown', () => {
  const service = serviceForTest();
  for (const [date, hours] of [['2026-03-08T00:00:00-05:00', 23], ['2026-11-01T00:00:00-04:00', 25]]) {
    service.clock = Date.parse(date);
    service._accept('Daily quote.');
    assert.equal(service._refreshDelay(), hours * 60 * 60 * 1000);
  }
  service.clock = Date.parse('2026-11-02T00:00:00-05:00');
  service.refresh();
  service.clock += 10000;
  service._accept('');
  assert.equal(service._snapshot.date, '2026-11-01', 'failed rollover preserves old quote');
  assert.equal(service._refreshDelay(), 50000);
  service._process.running = false;
  service.refresh();
  assert.equal(service._process.running, false);
  service.clock += 50000;
  service.refresh();
  assert.equal(service._process.running, true);
});

test('quote clock sleeps until its deadline and stops during requests', () => {
  assert.match(source, /interval: service\._refreshDelay\(\)/);
  assert.match(source, /running: service\._lastAttempt > 0 && !service\.loading/);
  assert.doesNotMatch(source, /interval: 1000/);
});

test('quote service rejects unsafe or malformed quote data', () => {
  const service = serviceForTest();
  service._accept('Keep going.\n');
  const previous = service._snapshot;
  for (const quote of ['<b>bad</b>', 'bad\nline']) {
    service._accept(quote);
    assert.equal(service._snapshot, previous);
    assert.equal(service._failure, 'Quote snapshot unavailable.');
  }
});
