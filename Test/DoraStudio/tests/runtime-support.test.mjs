import test from 'node:test';
import assert from 'node:assert/strict';
import { build } from 'esbuild';
const result = await build({ entryPoints: [new URL('../apps/web/src/runtime-support.ts', import.meta.url).pathname],
  bundle: true, write: false, platform: 'browser', format: 'esm' });
const { runtimeSupportProblem } = await import(`data:text/javascript;base64,${Buffer.from(result.outputFiles[0].text).toString('base64')}`);
test('runtime prerequisites report missing environment features without pretending success', () => {
  const supported = { secure: true, isolated: true, sharedMemory: true, offscreen: true, transferCanvas: true };
  assert.equal(runtimeSupportProblem(supported), null);
  assert.match(runtimeSupportProblem({ ...supported, secure: false }), /HTTPS/);
  for (const key of ['isolated', 'sharedMemory']) assert.match(runtimeSupportProblem({ ...supported, [key]: false }), /COOP/);
  for (const key of ['offscreen', 'transferCanvas']) assert.match(runtimeSupportProblem({ ...supported, [key]: false }), /画布/);
});
