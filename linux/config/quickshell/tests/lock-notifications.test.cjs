const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { execFileSync } = require('node:child_process');
const { test } = require('node:test');

const script = path.join(__dirname, '../../../scripts/lock-notifications');

function render(history, theme = 'dark') {
  const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'lock-notifications-'));
  const home = path.join(temporary, 'home');
  const state = path.join(temporary, 'state');
  const stateDirectory = path.join(state, 'dotfiles');
  fs.mkdirSync(stateDirectory, { recursive: true });

  fs.writeFileSync(
    path.join(stateDirectory, 'notifications.conf'),
    `[General]\nhistoryJson=${JSON.stringify(JSON.stringify(history))}\n`,
  );
  fs.writeFileSync(path.join(stateDirectory, 'color-scheme'), `${theme}\n`);

  const output = execFileSync(script, {
    encoding: 'utf8',
    env: { ...process.env, HOME: home, XDG_STATE_HOME: state },
  }).trim();
  const source = fs.readFileSync(output.replace(/\.png$/, '.svg'), 'utf8');

  return { temporary, source, output };
}

test('lock notification renderer emits themed cards with escaped content', () => {
  const result = render([{
    appName: 'Microsoft Teams',
    appIcon: '',
    summary: '<Unsafe>',
    body: 'teams.cloud.microsoft\nfirst <two> & more words',
    urgency: 'critical',
    time: Math.floor(Date.now() / 1000),
  }], 'light');

  try {
    assert.deepEqual([...fs.readFileSync(result.output).subarray(0, 8)], [137, 80, 78, 71, 13, 10, 26, 10]);
    assert.match(result.source, /^<svg [^>]+>/);
    assert.match(result.source, /fill="#E8EBEF"/);
    assert.match(result.source, /&lt;Unsafe&gt;/);
    assert.doesNotMatch(result.source, /first &lt;two&gt; &amp; more words/);
    assert.doesNotMatch(result.source, /teams\.cloud\.microsoft/);
    assert.match(result.source, /#5059c9/);
    assert.doesNotMatch(result.source, /<b>|<span /);
  } finally {
    fs.rmSync(result.temporary, { recursive: true, force: true });
  }
});

test('lock notification renderer keeps an informative empty notification state', () => {
  const result = render([]);

  try {
    assert.deepEqual([...fs.readFileSync(result.output).subarray(0, 8)], [137, 80, 78, 71, 13, 10, 26, 10]);
    assert.match(result.source, /^<svg [^>]+>/);
    assert.match(result.source, />Notifications<\/text>/);
    assert.match(result.source, />0 messages<\/text>/);
  } finally {
    fs.rmSync(result.temporary, { recursive: true, force: true });
  }
});
