import test from 'node:test';
import assert from 'node:assert/strict';
import { build } from 'esbuild';
const result = await build({ entryPoints: [new URL('../apps/web/src/resource-upload.ts', import.meta.url).pathname],
  bundle: true, write: false, platform: 'browser', format: 'esm' });
const { appendResources } = await import(`data:text/javascript;base64,${Buffer.from(result.outputFiles[0].text).toString('base64')}`);
test('upload preserves bytes, refuses collisions and leaves the original list unchanged', async () => {
  const original = [{ path: 'main.ts', kind: 'text', text: '' }];
  const file = new File([new Uint8Array([0, 255, 9])], 'sound.bin');
  const result = await appendResources(original, [file]);
  assert.equal(original.length, 1);
  assert.equal(result[1].path, 'Resources/sound.bin');
  assert.deepEqual([...result[1].bytes], [0, 255, 9]);
  await assert.rejects(appendResources(result, [file]), /冲突/);
  await assert.rejects(appendResources(original, [file, file]), /冲突/);
  await assert.rejects(appendResources(original, [new File(['x'], '../escape')]), /无效/);
  await assert.rejects(appendResources(original, [{ name: 'large', size: 64 * 1024 * 1024 + 1 }]), /64 MiB/);
  await assert.rejects(appendResources(original, [{ name: 'short', size: 2, arrayBuffer: async () => new ArrayBuffer(1) }]), /不完整/);
});
