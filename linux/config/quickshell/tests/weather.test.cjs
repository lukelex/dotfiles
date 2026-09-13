const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const vm = require('node:vm');
const { spawnSync } = require('node:child_process');
const { test } = require('node:test');

const script = path.resolve(__dirname, '../../../scripts/weather');
const source = fs.readFileSync(path.join(__dirname, '../WeatherService.qml'), 'utf8');
const now = Math.floor(Date.now() / 1000); // Freeze the clock while keeping filesystem mtimes comparable.
const weather = [{ id: 800, main: 'Clear', description: 'clear sky', icon: '01n' }];
const current = { cod: 200, name: 'Test City', sys: { country: 'XX' }, timezone: 19800,
  dt: now, main: { temp: 12.5, feels_like: 10, temp_min: 11, temp_max: 14, humidity: 60 },
  wind: { speed: 2.5 }, weather };

function fixture(t, offset = 19800, credentials = {}) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'weather-test-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  for (const dir of ['dotfiles/linux', 'bin', 'fixtures', 'cache/weather'])
    fs.mkdirSync(path.join(root, dir), { recursive: true });
  fs.writeFileSync(path.join(root, 'dotfiles/linux/variables.env'), '# No credentials in tests\n');
  if (credentials.localKey) {
    fs.mkdirSync(path.join(root, 'Dropbox'));
    fs.writeFileSync(path.join(root, 'Dropbox/secrets.env'), `export OPEN_WEATHER_API_KEY=${credentials.localKey}\n`);
  }
  fs.writeFileSync(path.join(root, 'bin/date'), `#!/bin/bash\nif [[ $1 == +%s ]]; then printf '%s\\n' ${now}; else /usr/bin/date "$@"; fi\n`, { mode: 0o755 });
  fs.writeFileSync(path.join(root, 'bin/curl'), `#!/bin/bash
printf 'request\\n' >> "$HOME/requests"
[[ $* == *--connect-timeout* && $* == *--max-time* ]] || exit 90
[[ \${!#} == *ipwho.is || $* == *"appid=$WEATHER_TEST_EXPECTED_KEY"* ]] || exit 22
[[ ! -f $HOME/offline ]] || exit 22
if [[ -f $HOME/malformed ]]; then printf '{"cod":200,"main":{"temp":"bad"}}'; exit; fi
if [[ -f $HOME/multiple ]]; then printf '{}\\n'; fi
if [[ -f $HOME/forecast-offline && \${!#} == */forecast ]]; then exit 22; fi
case "\${!#}" in
  *ipwho.is) /usr/bin/cat "$HOME/fixtures/location.json" ;;
  */weather) /usr/bin/cat "$HOME/fixtures/current.json" ;;
  */forecast) /usr/bin/cat "$HOME/fixtures/forecast.json" ;;
  *) exit 91 ;;
esac
`, { mode: 0o755 });
  const today = new Date((now + offset) * 1000).toISOString().slice(0, 10);
  const midnight = Date.parse(`${today}T00:00:00Z`) / 1000 - offset;
  const list = [];
  for (let day = 0; day < 5; day++) {
    for (const hour of [0, 3, 6, 9, 12, 15, 18, 21]) {
      list.push({ dt: Math.ceil(midnight / 10800) * 10800 + day * 86400 + hour * 3600,
        main: { temp: day + hour, temp_min: day - hour, temp_max: day + hour + 3 }, weather });
    }
  }
  const fixtures = { location: { success: true, city: 'Test City' },
    current: { ...current, timezone: offset }, forecast: { cod: '200', city: { timezone: offset }, list } };
  for (const [name, data] of Object.entries(fixtures))
    fs.writeFileSync(path.join(root, `fixtures/${name}.json`), JSON.stringify(data));
  const run = (...args) => {
    const result = spawnSync('bash', [script, ...args], {
      env: { ...process.env, HOME: root, XDG_CACHE_HOME: path.join(root, 'cache'),
        OPEN_WEATHER_API_KEY: credentials.inheritedKey ?? 'weather-test-key',
        WEATHER_TEST_EXPECTED_KEY: credentials.expectedKey ?? 'weather-test-key',
        PATH: `${root}/bin:/usr/bin:/bin`, TZ: 'Pacific/Honolulu' }, encoding: 'utf8', timeout: 5000,
    });
    assert.equal(result.status, 0, result.stderr);
    return args[0] === 'snapshot' ? JSON.parse(result.stdout) : result.stdout.trim();
  };
  const requests = () => fs.readFileSync(path.join(root, 'requests'), 'utf8').trim().split('\n').length;
  return { root, run, requests, midnight, offset };
}

test('service environment without an inherited key loads the existing local secrets file', t => {
  const f = fixture(t, 19800, { inheritedKey: '', localKey: 'weather-local-test-key', expectedKey: 'weather-local-test-key' });
  const result = f.run('snapshot');
  assert.equal(result.available, true);
  assert.equal(result.stale, false);
  assert.equal(result.error, '');
  assert.equal(f.requests(), 3);
});

test('explicit inherited weather key is not overwritten by local secrets', t => {
  const f = fixture(t, 19800, { localKey: 'weather-other-test-key' });
  assert.equal(f.run('snapshot').stale, false);
});

test('missing credentials are explicit and do not send unauthenticated provider requests', t => {
  const f = fixture(t, 19800, { inheritedKey: '' });
  const result = f.run('snapshot');
  assert.equal(result.available, false);
  assert.equal(result.stale, true);
  assert.match(result.error, /API key is not configured/);
  assert.equal(f.requests(), 1, 'only location is requested');
});

for (const offset of [19800, -25200]) {
  test(`snapshot groups all ranges using city offset ${offset}, retaining next three dates`, t => {
    const f = fixture(t, offset);
    const data = f.run('snapshot');
    assert.equal(data.available, true);
    assert.equal(data.loading, false);
    assert.equal(data.stale, false);
    assert.equal(data.error, '');
    assert.equal(data.temperature, 12.5);
    assert.equal(data.conditionCode, 800);
    assert.equal(data.conditionIcon, 'moon');
    assert.equal(data.isDay, false);
    assert.equal(data.timezoneOffset, offset);
    assert.equal(data.forecast.length, 3);
    for (let i = 0; i < 3; i++) {
      assert.equal(data.forecast[i].date,
        new Date((f.midnight + offset + (i + 1) * 86400) * 1000).toISOString().slice(0, 10));
      assert.equal(data.forecast[i].low, i + 1 - 21);
      assert.equal(data.forecast[i].high, i + 1 + 24);
      assert.ok(fs.existsSync(path.join(__dirname, '../../lucide/svg', `${data.forecast[i].icon}.svg`)));
    }
    assert.equal('low' in data, false, 'current observation min/max is not a daily range');
    f.run('snapshot');
    assert.equal(f.requests(), 3, '20-minute cache shares all three requests');
    assert.equal(f.run('details').split('|').length, 9);
    assert.equal(f.run('forecast').split('|').length, 3);
    assert.ok(f.run('icon').length);
    f.run('snapshot', '--refresh');
    assert.equal(f.requests(), 6, 'explicit refresh bypasses a successful fresh cache');
  });
}

for (const failure of ['offline', 'malformed', 'multiple']) {
  test(`${failure} refresh retains successful caches and timestamps, throttles forced retries`, t => {
    const f = fixture(t);
    f.run('snapshot');
    for (const name of ['location', 'current', 'forecast'])
      fs.utimesSync(path.join(f.root, `cache/weather/${name}.json`), now - 1300, now - 1300);
    const before = fs.readFileSync(path.join(f.root, 'cache/weather/current.json'), 'utf8');
    fs.writeFileSync(path.join(f.root, failure), '');
    const data = f.run('snapshot');
    assert.equal(data.available, true);
    assert.equal(data.stale, true);
    assert.ok(data.error);
    assert.equal(data.updatedAt, now - 1300);
    assert.equal(data.forecastUpdatedAt, now - 1300);
    assert.equal(fs.readFileSync(path.join(f.root, 'cache/weather/current.json'), 'utf8'), before);
    f.run('snapshot', '--refresh');
    assert.equal(f.requests(), 6);
    fs.unlinkSync(path.join(f.root, failure));
    for (const name of ['location', 'current', 'forecast'])
      fs.utimesSync(path.join(f.root, `cache/weather/${name}.json.failed`), now - 61, now - 61);
    assert.equal(f.run('snapshot').stale, false);
    assert.equal(f.requests(), 9);
  });
}

test('partial forecast failure retains its older timestamp and ranges while current updates', t => {
  const f = fixture(t);
  const previous = f.run('snapshot');
  fs.utimesSync(path.join(f.root, 'cache/weather/forecast.json'), now - 1300, now - 1300);
  fs.writeFileSync(path.join(f.root, 'forecast-offline'), '');
  const data = f.run('snapshot', '--refresh');
  assert.equal(data.available, true);
  assert.equal(data.stale, true);
  assert.ok(data.updatedAt >= now);
  assert.equal(data.forecastUpdatedAt, now - 1300);
  assert.deepEqual(data.forecast, previous.forecast);
});

test('failed forced refresh can recover after cooldown even when retained cache is fresh', t => {
  const f = fixture(t);
  f.run('snapshot');
  fs.writeFileSync(path.join(f.root, 'offline'), '');
  assert.equal(f.run('snapshot', '--refresh').stale, true);
  fs.unlinkSync(path.join(f.root, 'offline'));
  for (const name of ['location', 'current', 'forecast'])
    fs.utimesSync(path.join(f.root, `cache/weather/${name}.json.failed`), now - 61, now - 61);
  assert.equal(f.run('snapshot').stale, false);
  assert.equal(f.requests(), 9);
});

test('empty and corrupt caches yield explicit unavailable state on failure', t => {
  const f = fixture(t);
  fs.writeFileSync(path.join(f.root, 'offline'), '');
  fs.writeFileSync(path.join(f.root, 'cache/weather/current.json'), '{broken');
  const data = f.run('snapshot');
  assert.equal(data.available, false);
  assert.equal(data.stale, true);
  assert.equal(data.updatedAt, 0);
  assert.equal(data.temperature, null);
  assert.deepEqual(data.forecast, []);
  assert.ok(data.error);
  f.run('snapshot');
  assert.equal(f.requests(), 3);
});

for (const damage of ['missing', 'duplicate', 'irregular']) {
  test(`skips ${damage} slot day, retains complete days and their actual dates`, t => {
    const f = fixture(t);
    const file = path.join(f.root, 'fixtures/forecast.json');
    const data = JSON.parse(fs.readFileSync(file, 'utf8'));
    // Damage tomorrow, leaving the following two days complete. Day four must not fill the gap.
    if (damage === 'missing') data.list.splice(9, 1);
    if (damage === 'duplicate') data.list[9] = data.list[8];
    if (damage === 'irregular') data.list[9].dt += 60;
    fs.writeFileSync(file, JSON.stringify(data));
    const result = f.run('snapshot');
    assert.equal(result.stale, true);
    assert.match(result.error, /Incomplete forecast/);
    assert.deepEqual(result.forecast.map(row => row.date), [2, 3].map(day =>
      new Date((f.midnight + f.offset + day * 86400) * 1000).toISOString().slice(0, 10)));
    assert.equal(result.forecast[0].low, 2 - 21);
  });
}

test('wholly malformed forecast does not replace a good forecast cache', t => {
  const f = fixture(t);
  const previous = f.run('snapshot');
  const cache = path.join(f.root, 'cache/weather/forecast.json');
  const before = fs.readFileSync(cache, 'utf8');
  fs.writeFileSync(path.join(f.root, 'fixtures/forecast.json'), '{"cod":"200","list":[null]}');
  const result = f.run('snapshot', '--refresh');
  assert.equal(result.stale, true);
  assert.deepEqual(result.forecast, previous.forecast);
  assert.equal(fs.readFileSync(cache, 'utf8'), before);
});

test('condition codes and actual day/night select the agreed asset names', t => {
  const f = fixture(t);
  for (const [id, icon, expected] of [[800, '01d', 'sun'], [800, '01n', 'moon'],
    [801, '02d', 'cloud-sun'], [801, '02n', 'cloud-moon'], [802, '03d', 'cloud'],
    [804, '04n', 'cloud'], [500, '10d', 'cloud-rain'], [600, '13n', 'cloud-snow'],
    [741, '50n', 'cloud-fog'], [200, '11d', 'cloud-lightning'], [300, '09n', 'cloud-drizzle']]) {
    fs.writeFileSync(path.join(f.root, 'fixtures/current.json'), JSON.stringify({ ...current,
      weather: [{ ...weather[0], id, icon }] }));
    const forecastPath = path.join(f.root, 'fixtures/forecast.json');
    const daily = JSON.parse(fs.readFileSync(forecastPath, 'utf8'));
    daily.list.forEach(slot => { slot.weather = [{ ...weather[0], id, icon }]; });
    fs.writeFileSync(forecastPath, JSON.stringify(daily));
    const result = f.run('snapshot', '--refresh');
    assert.equal(result.conditionIcon, expected);
    assert.equal(result.forecast[0].icon, expected);
  }
});

function serviceForTest() {
  const service = { _snapshot: {}, _lastAttempt: 0, _process: { running: false }, loading: false, stale: true };
  service.clock = now * 1000;
  const context = vm.createContext({ service, Date: class extends Date { static now() { return service.clock; } } });
  for (const name of ['refresh', '_accept', '_tick']) {
    const match = source.match(new RegExp(`^( +)function ${name}\\([^]*?\\n\\1\\}`, 'm'));
    assert.ok(match);
    service[name] = vm.runInContext(`(${match[0]})`, context);
  }
  return service;
}

test('service starts lazily, deduplicates refreshes and enforces retry cooldown even for force', () => {
  const s = serviceForTest();
  assert.equal(s._process.running, false);
  s.refresh();
  assert.equal(s.loading, true);
  assert.equal(s._process.running, true);
  const attempt = s._lastAttempt;
  s.refresh(true);
  assert.equal(s._force, false);
  s.loading = false;
  s._process.running = false;
  s.refresh(true);
  assert.equal(s._process.running, false);
  s._lastAttempt = attempt - 61;
  s.refresh(true);
  assert.equal(s._force, true);
});

test('service accepts one shared snapshot and preserves it after malformed process output', () => {
  const s = serviceForTest();
  s._accept(JSON.stringify({ available: true, stale: false, updatedAt: now,
    temperature: 12, feelsLike: 10, forecast: [] }));
  assert.equal(s._snapshot.temperature, 12);
  assert.equal(s._failed, false);
  s._accept('{"available":true}');
  assert.equal(s._snapshot.temperature, 12);
  assert.equal(s._failed, true);
  assert.ok(s._failure);
  assert.equal(s.loading, false);
});

test('service rejects malformed forecast rows without replacing its good snapshot', () => {
  const s = serviceForTest();
  const row = { date: '2028-02-29', low: 1, high: 5, icon: 'cloud-rain', condition: 'Rain' };
  const data = { available: true, stale: false, updatedAt: now, temperature: 12, feelsLike: 10, forecast: [row] };
  s._accept(JSON.stringify(data));
  assert.equal(s._failed, false);
  const previous = s._snapshot;
  for (const bad of [null, {}, { ...row, date: '2027-02-29' }, { ...row, date: '2028-13-01' },
    { ...row, date: '2028-2-29' }, { ...row, low: null }, { ...row, high: '5' },
    { ...row, low: 10 }, { ...row, icon: '../sun' }, { ...row, condition: '<b>Rain</b>' },
    { ...row, condition: '' }, { ...row, condition: '\nRain' }]) {
    s._accept(JSON.stringify({ ...data, forecast: [bad] }));
    assert.equal(s._failed, true, JSON.stringify(bad));
    assert.equal(s._snapshot, previous);
  }
});

test('expiry refreshes within a timer tick, respects pending work and cooldown, then stops retrying fresh data', () => {
  const s = serviceForTest();
  s._tick();
  assert.equal(s._process.running, false, 'no startup fetch');
  s._lastAttempt = now - 1199;
  s.updatedAt = now - 1190; // Fetch completed nine seconds after the initial attempt.
  s._snapshot = { forecastUpdatedAt: s.updatedAt, locationUpdatedAt: s.updatedAt };
  s.stale = false;
  s.clock += 1000;
  s._tick();
  assert.equal(s._process.running, true, 'periodic attempt can reuse a not-quite-expired cache');
  s.loading = false;
  s._process.running = false;
  s.clock += 30000;
  s.stale = true;
  s._tick();
  assert.equal(s._process.running, false, 'expiry respects the sixty-second cooldown');
  s.clock += 30000;
  s._tick();
  assert.equal(s._process.running, true, 'expiry does not wait another twenty minutes');
  const attempt = s._lastAttempt;
  s.clock += 60000;
  s._tick();
  assert.equal(s._lastAttempt, attempt, 'no competing request while loading');
  s.loading = false;
  s._process.running = false;
  s.updatedAt = s.clock / 1000;
  s._snapshot = { forecastUpdatedAt: s.updatedAt, locationUpdatedAt: s.updatedAt };
  s.stale = true; // An incomplete but freshly fetched forecast must not create a retry loop.
  s.clock += 30000;
  s._tick();
  assert.equal(s._process.running, false);
});
