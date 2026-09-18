import assert from 'node:assert/strict';
import createLua from '../packages/agent-contracts/dist/lua/syntax.mjs';
const module = await createLua();
const error = module.cwrap('syntax_error', 'string', []);
function check(source) {
  const bytes = new TextEncoder().encode(source);
  const pointer = module._malloc(Math.max(1, bytes.length));
  try {
    module.HEAPU8.set(bytes, pointer);
    const status = module._syntax_check(pointer, bytes.length);
    return { status, message: status ? error() : '' };
  } finally { module._free(pointer); module._syntax_close(); }
}
assert.equal(check('return 42').status, 0);
assert.equal(check('while true do end').status, 0); // Must parse without executing.
assert.equal(check('error("must not execute")').status, 0);
assert.notEqual(check('local =').status, 0);
assert.match(check('local =').message, /check.*1/);
assert.equal(check('return "中文"').status, 0);
assert.notEqual(check('return 1\0invalid').status, 0); // Length is explicit, not strlen.
assert.equal(check('local x = 1\nreturn x').status, 0);
console.log('PASS engine Lua Wasm syntax: valid/invalid input, no execution, UTF-8, embedded NUL and recovery; Teal checks not included');
