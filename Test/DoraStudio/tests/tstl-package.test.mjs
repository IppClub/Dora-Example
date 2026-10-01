import test from 'node:test';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { build } from 'esbuild';
import pathAdapter from '@dora-studio/tstl/path';

const require = createRequire(import.meta.url);

test('TSTL browser bundle is independent of native IDE sources and Node built-ins', async () => {
  const result = await build({
    entryPoints: [require.resolve('@dora-studio/tstl')], bundle: true,
    format: 'esm', platform: 'browser', write: false, metafile: true,
    alias: {
      path: require.resolve('@dora-studio/tstl/path'),
      typescript: require.resolve('@dora-studio/tstl/browser-typescript'),
      url: require.resolve('@dora-studio/tstl/browser-url'),
    },
    logLevel: 'silent',
  });
  assert.ok(result.outputFiles[0].contents.length > 1000);
  assert.ok(Object.keys(result.metafile.inputs).every(path => !/(?:^|\/)Tools\/dora-dora\/src\//.test(path)),
    'the compiler bundle must not consume native Web IDE source; shared node_modules paths are allowed');
  for (const output of Object.values(result.metafile.outputs)) assert.deepEqual(output.imports, []);
});

test('packaged TSTL works with modern class-field semantics', async () => {
  const temp = await mkdtemp(join(tmpdir(), 'studio-tstl-fields-'));
  try {
    const outfile = join(temp, 'tstl.cjs');
    await build({ entryPoints: [require.resolve('@dora-studio/tstl')], outfile,
      bundle: true, format: 'cjs', platform: 'node',
      tsconfigRaw: { compilerOptions: { useDefineForClassFields: true } }, logLevel: 'silent' });
    const tstl = require(outfile);
    const result = tstl.transpileVirtualProject({ 'main.ts': 'export const answer = 42;' }, { noHeader: true });
    assert.match(result.transpiledFiles.find(file => file.lua)?.lua, /42/);
    assert.equal(result.diagnostics.filter(d => d.source === 'typescript-to-lua').length, 0);
  } finally { await rm(temp, { recursive: true, force: true }); }
});

test('shared path adapter preserves native platform switching without IDE globals', () => {
  try {
    pathAdapter.setPath(pathAdapter.posix);
    assert.equal(pathAdapter.normalize('/game/a/../main.ts'), '/game/main.ts');
    assert.equal(pathAdapter.relative('/game', '/game/logic/value.ts'), 'logic/value.ts');
    pathAdapter.setPath(pathAdapter.win32);
    assert.equal(pathAdapter.normalize('C:\\game\\a\\..\\main.ts'), 'C:\\game\\main.ts');
    assert.equal(pathAdapter.basename('C:\\game\\main.ts'), 'main.ts');
  } finally { pathAdapter.setPath(pathAdapter.posix); }
});
