// sql-language-server 1.7.1 still expects Node's removed SlowBuffer export.
// Keep the compatibility alias local to sqlls instead of changing Node globally.
const buffer = require("node:buffer");

if (buffer.SlowBuffer === undefined) {
  buffer.SlowBuffer = buffer.Buffer;
}
