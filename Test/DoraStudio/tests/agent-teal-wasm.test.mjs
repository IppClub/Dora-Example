import test from 'node:test';

// Keep the real Wasm compiler and the shared Lua corpus in Studio's default CI
// run, alongside the browser acceptance script used for Worker/tool parity.
test('real Studio Teal Wasm preserves Lua global-write checks and diagnostics', async () => {
  await import('./agent-teal-wasm.mjs');
});
