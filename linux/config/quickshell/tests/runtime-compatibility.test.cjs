const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { test } = require('node:test');

const configRoot = path.resolve(__dirname, '..');

// APIs observed to be missing from the Qt/QV4 JavaScript runtime used by
// Quickshell. Add entries here when a runtime incompatibility is discovered;
// Node-based tests alone do not establish that an API exists in QML.
const unsupportedApis = [
  { name: 'Array.prototype.flatMap', pattern: /\.flatMap\s*\(/ },
];

function sourceFiles(directory) {
  const files = [];
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    if (entry.name === 'tests')
      continue;
    const fullPath = path.join(directory, entry.name);
    if (entry.isDirectory())
      files.push(...sourceFiles(fullPath));
    else if (entry.isFile() && /\.(?:qml|js)$/.test(entry.name))
      files.push(fullPath);
  }
  return files;
}

test('Quickshell sources avoid JavaScript APIs missing from the Qt runtime', () => {
  const violations = [];
  for (const file of sourceFiles(configRoot)) {
    const lines = fs.readFileSync(file, 'utf8').split(/\r?\n/);
    for (const api of unsupportedApis) {
      lines.forEach((line, index) => {
        if (api.pattern.test(line))
          violations.push(`${path.relative(configRoot, file)}:${index + 1}: ${api.name}`);
      });
    }
  }

  assert.deepEqual(violations, [],
    `Unsupported JavaScript API usage found in Quickshell sources:\n${violations.join('\n')}`);
});
