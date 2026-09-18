import test from 'node:test';
import assert from 'node:assert/strict';
import { validateEditFile } from '../packages/agent-contracts/dist/edit-validation.js';
import { getToolDefinition } from '../packages/agent-contracts/dist/index.js';
import { executeAgentToolDefinition } from '../packages/agent-contracts/dist/executor.js';

test('original edit semantics reject mixed formats but preserve per-operation batch failures for the handler', async () => {
  for (const input of [{ path: 'a' }, { path: 'a', old_str: 'same', new_str: 'same' },
    { path: ' ', old_str: '', new_str: 'new' }, { edits: [] },
    { edits: [{ path: 'a', old_str: '', new_str: 'new' }], old_str: '', new_str: 'mixed' }]) {
    assert.equal(validateEditFile(input).success, false);
  }
  const input = { path: ' shared.lua ', edits: [{ old_str: '', new_str: 'new' }, { path: 'b', old_str: 'same', new_str: 'same' }] };
  const before = structuredClone(input);
  const validated = validateEditFile(input);
  assert.equal(validated.success, true);
  assert.deepEqual(validated.value.edits, [{ path: 'shared.lua', old_str: '', new_str: 'new' }, { path: 'b', old_str: 'same', new_str: 'same' }]);
  assert.deepEqual(input, before);
  let calls = 0;
  const definition = { ...getToolDefinition('edit_file'), validateInput: validateEditFile,
    handler: async () => { calls++; return { output: { success: true } }; } };
  const context = { role: 'main', workMode: 'code', disabledAgentTools: [], cancellation: { isCancelled: () => false, reason: () => undefined } };
  const result = await executeAgentToolDefinition(definition, { path: 'a', old_str: 'x', new_str: 'x' }, context, { searchDoraDocLimitMax: 20 });
  assert.equal(result.output.code, 'INVALID_TOOL_INPUT');
  assert.equal(calls, 0);
});
