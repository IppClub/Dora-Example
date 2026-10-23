import test from 'node:test';
import assert from 'node:assert/strict';
import { validateReadFile } from '../packages/agent-contracts/dist/read-validation.js';
import { getToolDefinition } from '../packages/agent-contracts/dist/index.js';
import { executeAgentToolDefinition } from '../packages/agent-contracts/dist/executor.js';

test('original read semantics retain defaults, negative lines and ordered mixed batches', () => {
  assert.deepEqual(validateReadFile({ path: ' main.ts ' }).value, { path: 'main.ts', startLine: 1, endLine: undefined });
  assert.deepEqual(validateReadFile({ path: 'a', startLine: -2 }).value, { path: 'a', startLine: -2, endLine: undefined });
  const result = validateReadFile({ path: 'first', reads: [{ path: 'second', startLine: 2.9 }] });
  assert.deepEqual(result.value.reads, [{ path: 'first', startLine: 1, endLine: undefined }, { path: 'second', startLine: 2, endLine: undefined }]);
  for (const input of [{ path: ' ' }, { path: 'a', startLine: 0 }, { path: 'a', endLine: 0 }, { reads: [{ path: 'a' }], startLine: 1 }]) {
    assert.equal(validateReadFile(input).success, false);
  }
});
test('read semantic rejection prevents handler dispatch through the shared executor', async () => {
  let calls = 0;
  let dispatched;
  const definition = { ...getToolDefinition('read_file'), validateInput: validateReadFile,
    handler: async (_, input) => { calls++; dispatched = input; return { output: { success: true } }; } };
  const context = { role: 'main', workMode: 'code', disabledAgentTools: [], cancellation: { isCancelled: () => false, reason: () => undefined } };
  const run = input => executeAgentToolDefinition(definition, input, context, { searchDoraDocLimitMax: 20 });
  assert.equal((await run({ path: 'a', startLine: 0 })).output.code, 'INVALID_TOOL_INPUT');
  assert.equal(calls, 0);
  assert.equal((await run({ path: 'a' })).output.success, true);
  assert.equal(dispatched.startLine, 1);
  assert.equal(dispatched.endLine, undefined);
  assert.equal(calls, 1);
});
