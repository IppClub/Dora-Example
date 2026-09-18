import assert from 'node:assert/strict';
import { readFile, readdir } from 'node:fs/promises';
import createTeal from '../packages/agent-contracts/dist/teal/compiler.mjs';
const module = await createTeal();
const error = module.cwrap('teal_error', 'string', []);
assert.equal(module._teal_open(), 0, error());
const addFile = module.cwrap('teal_add_file', null, ['string', 'number', 'number']);
const checkCode = module.cwrap('teal_check', 'number', ['number', 'number', 'string', 'number']);
const diagnostic = module.cwrap('teal_diagnostic', 'string', ['number', 'number']);
const checkLua = module.cwrap('teal_check_lua', 'number', ['number', 'number', 'string']);
const removeFile = module.cwrap('teal_remove_file', null, ['string']);
const compileCode = module.cwrap('teal_compile', 'number', ['number', 'number', 'string']);
const compiledSource = module.cwrap('teal_compiled_source', 'string', []);
function withBytes(text, action) {
  const bytes = new TextEncoder().encode(text), pointer = module._malloc(Math.max(1, bytes.length));
  assert.ok(pointer);
  try { module.HEAPU8.set(bytes, pointer); return action(pointer, bytes.length); }
  finally { module._free(pointer); }
}
async function declarations(directory, prefix = '') {
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    if (entry.isDirectory()) await declarations(new URL(entry.name + '/', directory), prefix + entry.name + '/');
    else if (entry.name.endsWith('.d.tl')) {
      withBytes(await readFile(new URL(entry.name, directory), 'utf8'), (pointer, length) => addFile(prefix + entry.name, pointer, length));
    }
  }
}
function check(text, filename = 'main.tl', lax = false) {
  const status = withBytes(text, (pointer, length) => checkCode(pointer, length, filename, +lax));
  assert.notEqual(status, 2, error());
  const count = module._teal_diagnostic_count();
  const diagnostics = Array.from({ length: count }, (_, i) => Array.from({ length: 5 }, (_, j) => diagnostic(i + 1, j + 1)));
  return { status, diagnostics };
}
try {
  await declarations(new URL('../../Assets/Script/Lib/Dora/en/', import.meta.url));
  assert.equal(module._teal_init(), 0, error());
  const good = check('local x: number = 1\nreturn x');
  assert.equal(good.status, 0, JSON.stringify(good));
  const bad = check('local x: number = "wrong"\nreturn x');
  assert.equal(bad.status, 1);
  assert.ok(bad.diagnostics.some(row => row[0] === 'type'), JSON.stringify(bad));
  const parsedOnly = check('while true do end', 'main.lua', true);
  assert.equal(parsedOnly.status, 0, JSON.stringify(parsedOnly));
  const recovered = check('local x: number = 2\nreturn x');
  assert.equal(recovered.status, 0, JSON.stringify(recovered));
  assert.equal(withBytes('local =', (pointer, length) => checkLua(pointer, length, 'game.lua')), 1);
  assert.equal(diagnostic(1, 1), 'syntax');
  assert.equal(diagnostic(1, 2), 'game.lua');
  assert.equal(withBytes('while true do end', (pointer, length) => checkLua(pointer, length, 'game.lua')), 0);
  assert.equal(withBytes('unknown_global()', (pointer, length) => checkLua(pointer, length, 'game.lua')), 0);
  assert.equal(withBytes('-- tic80\nreturn 1', (pointer, length) => checkLua(pointer, length, 'game.lua')), 0);
  assert.equal(withBytes('-- tic80', (pointer, length) => checkLua(pointer, length, 'game.lua')), 0);
  // The original detector accepts a dollar marker; substitution exposes its syntax error.
  assert.equal(withBytes('-- tic80$', (pointer, length) => checkLua(pointer, length, 'game.lua')), 1);
  assert.equal(diagnostic(1, 1), 'syntax');
  const dependency = text => withBytes(text, (pointer, length) => addFile('dependency.tl', pointer, length));
  const source = 'local dependency = require("dependency")\nlocal value: number = dependency\nreturn value';
  dependency('local value: number = 1\nreturn value');
  assert.equal(check(source).status, 0);
  dependency('local value: string = "changed"\nreturn value');
  const changed = check(source);
  assert.equal(changed.status, 1, JSON.stringify(changed));
  assert.ok(changed.diagnostics.some(row => row[0] === 'type'));
  removeFile('dependency.tl');
  const missing = check(source);
  assert.equal(missing.status, 1, JSON.stringify(missing));
  dependency('local value: number = 2\nreturn value');
  assert.equal(check(source).status, 0);
  const compileStatus = withBytes(source, (pointer, length) => compileCode(pointer, length, 'main.tl'));
  assert.equal(compileStatus, 0, error());
  const lua = compiledSource();
  assert.match(lua, /require/);
  assert.doesNotMatch(lua, /: number/);
  const invalidCompile = withBytes('local value: number = "bad"', (pointer, length) => compileCode(pointer, length, 'main.tl'));
  assert.equal(invalidCompile, 1);
  assert.ok(error().length > 0);
  console.log('PASS original Teal Wasm: real Dora declarations, type diagnostics, no execution, changed/deleted dependency cache isolation, recovery and Lua generation');
} finally { module._teal_close(); }
