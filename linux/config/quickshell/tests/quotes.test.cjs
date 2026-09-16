const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { test } = require('node:test');

const script = path.resolve(__dirname, '../../../scripts/quotes');

function fixture(t) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'quotes-test-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  fs.mkdirSync(path.join(root, 'bin'), { recursive: true });
  fs.writeFileSync(path.join(root, 'bin/curl'), '#!/bin/bash\nprintf \'{"contents":{"quotes":[{"quote":"A reliable test quote."}]}}\'\n', { mode: 0o755 });
  const run = (...args) => spawnSync('bash', [script, ...args], {
    env: { ...process.env, HOME: root, XDG_CACHE_HOME: path.join(root, 'cache'),
      QUOTES_API_KEY: 'test-key', PATH: `${root}/bin:/usr/bin:/bin`, TZ: 'Pacific/Honolulu' },
    encoding: 'utf8',
  });
  return { root, run, cache: path.join(root, 'cache/quotes') };
}

test('gets one quote per local calendar day and reuses the daily cache', t => {
  const f = fixture(t);
  const first = f.run('get');
  assert.equal(first.status, 0, first.stderr);
  assert.equal(first.stdout.trim(), 'A reliable test quote.');
  const cached = fs.readdirSync(f.cache);
  assert.equal(cached.length, 1);
  const second = f.run('snapshot');
  assert.equal(second.status, 0, second.stderr);
  assert.deepEqual(JSON.parse(second.stdout), {
    available: true,
    date: cached[0],
    quote: 'A reliable test quote.',
    stale: false,
    error: '',
  });
});

test('uses the newest valid cached quote when the daily request fails', t => {
  const f = fixture(t);
  fs.mkdirSync(f.cache, { recursive: true });
  fs.writeFileSync(path.join(f.cache, '2020-01-01'), 'Older quote.\n');
  fs.writeFileSync(path.join(f.cache, '2025-01-01'), 'Newest cached quote.\n');
  fs.writeFileSync(path.join(f.cache, '2026-01-01'), '\n');
  fs.writeFileSync(path.join(f.root, 'bin/curl'), '#!/bin/bash\nexit 1\n', { mode: 0o755 });
  const result = f.run('snapshot');
  assert.equal(result.status, 0, result.stderr);
  assert.equal(JSON.parse(result.stdout).quote, 'Newest cached quote.');
  assert.equal(JSON.parse(result.stdout).stale, true);
  assert.match(JSON.parse(result.stdout).error, /cached/);
});

test('reports unavailable without credentials and rejects corrupt cache data', t => {
  const f = fixture(t);
  fs.mkdirSync(f.cache, { recursive: true });
  const date = new Intl.DateTimeFormat('en-CA', { timeZone: 'Pacific/Honolulu', year: 'numeric', month: '2-digit', day: '2-digit' }).format(new Date()).replaceAll('/', '-');
  fs.writeFileSync(path.join(f.cache, date), '');
  const result = spawnSync('bash', [script, 'snapshot'], {
    env: { ...process.env, HOME: f.root, XDG_CACHE_HOME: path.join(f.root, 'cache'), QUOTES_API_KEY: '', PATH: `${f.root}/bin:/usr/bin:/bin`, TZ: 'Pacific/Honolulu' },
    encoding: 'utf8',
  });
  assert.equal(result.status, 0);
  const snapshot = JSON.parse(result.stdout);
  assert.equal(snapshot.available, false);
  assert.equal(snapshot.quote, '');
  assert.match(snapshot.error, /unavailable/);
});
