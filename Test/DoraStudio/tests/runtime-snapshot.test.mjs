import test from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { build } from 'esbuild';
import { serializeArtifactContent } from '../packages/contracts/dist/index.js';
const bundled = await build({ entryPoints: [new URL('../apps/web/src/runtime-snapshot.ts', import.meta.url).pathname],
  bundle: true, write: false, platform: 'browser', format: 'esm', target: 'es2022' });
const { prepareRuntimeSnapshot } = await import(`data:text/javascript;base64,${Buffer.from(bundled.outputFiles[0].text).toString('base64')}`);
const hash = data => createHash('sha256').update(data).digest('hex');
function artifact() {
  const value = { projectId: 'p', revision: 2, buildId: 'build2', compilerVersion: 'test',
    entry: 'init.lua', sourceMaps: {}, files: [
      { path: 'init.lua', kind: 'text', text: 'print("你好")' },
      { path: 'image.bin', kind: 'binary', bytes: new Uint8Array([0, 255, 10]) },
    ] };
  return { ...value, sha256: hash(serializeArtifactContent(value)) };
}
test('runtime snapshot preserves exact text/binary bytes and build identity without networking', async () => {
  const input = artifact();
  const result = await prepareRuntimeSnapshot(input, '1.9.3');
  assert.deepEqual(result.identity, { projectId: 'p', revision: 2, buildId: 'build2', sha256: input.sha256 });
  assert.equal(new TextDecoder().decode(result.files[0].bytes), 'print("你好")');
  assert.deepEqual([...result.files[1].bytes], [0, 255, 10]);
  for (let i = 0; i < result.files.length; i++) {
    assert.equal(result.manifest.files[i].sha256, hash(result.files[i].bytes));
    assert.equal(result.manifest.files[i].size, result.files[i].bytes.byteLength);
  }
});
test('runtime snapshot rejects tampering and isolates mutation during async hashing', async () => {
  const invalid = artifact(); invalid.files[0].text = 'changed';
  await assert.rejects(prepareRuntimeSnapshot(invalid, '1.9.3'), /完整性/);
  const input = artifact(); const pending = prepareRuntimeSnapshot(input, '1.9.3');
  input.files[1].bytes.fill(42); input.revision = 100;
  const result = await pending;
  assert.deepEqual([...result.files[1].bytes], [0, 255, 10]);
  assert.equal(result.identity.revision, 2);
  await assert.rejects(prepareRuntimeSnapshot(null), /无效/);
});
