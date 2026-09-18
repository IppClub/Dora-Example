import test from 'node:test';
import assert from 'node:assert/strict';
import { build } from 'esbuild';
const result = await build({ entryPoints: [new URL('../apps/web/src/runtime-storage.ts', import.meta.url).pathname], bundle: true,
  write: false, platform: 'browser', format: 'esm', target: 'es2022' });
const { runtimeStorageId } = await import(`data:text/javascript;base64,${Buffer.from(result.outputFiles[0].text).toString('base64')}`);
test('preview storage namespace is stable and separated by project and Studio origin', async () => {
  const id = await runtimeStorageId('https://studio.example', 'p');
  assert.equal(await runtimeStorageId('https://studio.example', 'p'), id);
  assert.notEqual(await runtimeStorageId('https://studio.example', 'other'), id);
  assert.notEqual(await runtimeStorageId('https://other.example', 'p'), id);
  assert.match(await runtimeStorageId('https://studio.example', '../中文/'.repeat(100)), /^preview-[a-f0-9]{64}$/);
});
