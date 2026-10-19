import test, { after } from 'node:test';
import assert from 'node:assert/strict';
import { readFile, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createRequire } from 'node:module';
import ts from 'typescript';
import { createSnapshotProgram, compileSnapshot, doraCompilerOptions, normalizePath } from '../packages/compiler/dist/index.js';

const require = createRequire(import.meta.url);
const { build } = require('esbuild');
const temp = await mkdtemp(join(tmpdir(), 'studio-compiler-test-'));
after(() => rm(temp, { recursive: true, force: true }));
await build({
  entryPoints: [require.resolve('@dora-studio/tstl')],
  outfile: join(temp, 'tstl.cjs'), bundle: true, platform: 'node', format: 'cjs', logLevel: 'silent',
});
const tstl = require(join(temp, 'tstl.cjs'));
const declarations = await Promise.all(['Dora.d.ts', 'es6-subset.d.ts', 'lua.d.ts', 'jsx.d.ts'].map(async name => ({
  file: `/dora/${name}`, content: await readFile(new URL(`../../Assets/Script/Lib/Dora/en/${name}`, import.meta.url), 'utf8'),
})));
const lualib = await readFile(new URL('../../Assets/Script/Lib/lualib_bundle.lua', import.meta.url), 'utf8');
const options = doraCompilerOptions(ts, tstl.LuaTarget.Lua55, tstl.LuaLibImportKind.Require);
function input(sources, root = '/project') {
  return {
    rootNames: [`${root}/main.ts`], projectRoot: root, options, defaultLibFileName: '/dora/Dora.d.ts',
    files: [...declarations, { file: 'lualib_bundle.lua', content: lualib },
      ...Object.entries(sources).map(([file, content]) => ({ file, content }))],
  };
}
const emit = (program, emitHost, writeFile) => new tstl.Transpiler({ emitHost }).emit({ program, writeFile }).diagnostics;
const compile = data => compileSnapshot(ts, data, emit);
const messages = result => result.diagnostics.map(d => `${d.code} ${ts.flattenDiagnosticMessageText(d.messageText, '\n')}`);

test('compiler options retain Dora Lua55 and existing strict Classic resolution', () => {
  assert.equal(options.luaTarget, tstl.LuaTarget.Lua55);
  assert.equal(options.noImplicitSelf, true);
  assert.equal(options.moduleResolution, ts.ModuleResolutionKind.Classic);
  assert.equal(normalizePath('C:\\work\\a\\..\\main.ts'), 'C:/work/main.ts');
});

test('real TSTL compiles nested imports and emits every source with maps', () => {
  const result = compile(input({
    'main.ts': 'import { answer } from "logic/value"; export const score = answer + 1;',
    'logic/value.ts': 'export const answer = 41;',
  }));
  assert.deepEqual(messages(result), []);
  assert.match(result.output.get('/project/main.lua').content, /logic.value/);
  assert.match(result.output.get('/project/logic/value.lua').content, /41/);
  assert.ok(result.output.has('/project/main.lua.map'));
});

test('Dora and lualib declarations compile against the actual bundled assets', () => {
  const result = compile(input({ 'main.ts': 'import { Vec2 } from "Dora"; export const point = Vec2(2, 3); export const values = [1, 2].map(x => x + 1);' }));
  assert.deepEqual(messages(result), []);
  assert.match(result.output.get('/project/main.lua').content, /Vec2/);
  assert.ok(result.output.has('/project/lualib_bundle.lua'));
});

test('missing snapshot dependency is an error, never satisfied from disk or prior build', () => {
  const valid = compile(input({ 'main.ts': 'import { x } from "other"; export const y = x;', 'other.ts': 'export const x = 1;' }));
  assert.deepEqual(messages(valid), []);
  const missing = compile(input({ 'main.ts': 'import { x } from "other"; export const y = x;' }));
  assert.ok(missing.diagnostics.some(d => d.code === 2792), messages(missing).join('\n'));
  const { host } = createSnapshotProgram(ts, input({ 'main.ts': '' }));
  assert.equal(host.readFile('/etc/passwd'), undefined);
  assert.equal(host.readFile('other.ts'), undefined);
});

test('relative import restriction remains a Dora diagnostic', () => {
  const result = compile(input({ 'main.ts': 'import { x } from "./other"; export const y = x;', 'other.ts': 'export const x = 1;' }));
  assert.ok(messages(result).some(message => message.includes('Relative path imports')));
});

test('diagnostics retain dependent file and source offset; next snapshot recovers', () => {
  const result = compile(input({ 'main.ts': 'export { x } from "./other";', 'other.ts': 'export const x: number = "wrong";' }));
  const diagnostic = result.diagnostics.find(d => d.code === 2322);
  assert.equal(diagnostic.file.fileName, '/project/other.ts');
  assert.equal(typeof diagnostic.start, 'number');
  const recovered = compile(input({ 'main.ts': 'export { x } from "./other";', 'other.ts': 'export const x: number = 1;' }));
  assert.deepEqual(messages(recovered), []);
});

test('snapshot host copies its input and isolates projects with equal filenames', () => {
  const data = input({ 'main.ts': 'export const value = 11;' });
  const { host } = createSnapshotProgram(ts, data);
  data.files.find(f => f.file === 'main.ts').content = 'export const value = 99;';
  assert.match(host.readFile('main.ts'), /11/);
  const a = compile(input({ 'main.ts': 'export const value = 11;' }, '/a'));
  const b = compile(input({ 'main.ts': 'export const value = 22;' }, '/b'));
  assert.match(a.output.get('/a/main.lua').content, /11/);
  assert.match(b.output.get('/b/main.lua').content, /22/);
});

test('explicit module aliases resolve but duplicate and ambiguous inputs fail', () => {
  const data = input({ 'main.ts': 'import { value } from "Shared"; export const x = value;' });
  data.files.push({ file: '/project/lib/shared.ts', moduleName: 'Shared', content: 'export const value = 7;' });
  const { program } = createSnapshotProgram(ts, data);
  assert.deepEqual(ts.getPreEmitDiagnostics(program).filter(d => ![2497, 2666].includes(d.code)), []);
  const result = compile(data);
  assert.deepEqual(messages(result), []);
  assert.match(result.output.get('/project/main.lua').content, /lib.shared/);
  data.files.push({ file: '/project/lib/other.ts', moduleName: 'Shared', content: '' });
  assert.throws(() => createSnapshotProgram(ts, data), /Ambiguous/);
  const duplicate = input({ 'main.ts': '' });
  duplicate.files.push({ file: '/project/main.ts', content: '' });
  assert.throws(() => createSnapshotProgram(ts, duplicate), /Duplicate/);
});

for (const [name, source] of [
  ['plain script', 'const value = 1; function drawBaby() { return value; } drawBaby();'],
  ['module marker', 'const value = 1; function drawBaby() { return value; } export {};'],
  ['Dora import', 'import {App} from "Dora"; const value = 1; function drawBaby() { return value; } const platform = App.platform;'],
]) {
  test(`top-level declarations stay local: ${name}`, () => {
    const result = compile(input({'main.ts': source}));
    assert.deepEqual(messages(result), []);
    const lua = result.output.get('/project/main.lua').content;
    assert.match(lua, /local value = 1/);
    assert.match(lua, /local function drawBaby/);
    assert.doesNotMatch(lua, /^value =|^function drawBaby/m);
  });
}
