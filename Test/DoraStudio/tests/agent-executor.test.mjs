import test from 'node:test';
import assert from 'node:assert/strict';
import { getToolDefinition } from '../packages/agent-contracts/dist/index.js';
import { executeAgentToolDefinition, executeRegisteredAgentTool } from '../packages/agent-contracts/dist/executor.js';

const schemaContext = { searchDoraDocLimitMax: 20 };
const context = (isCancelled = () => false) => ({ role: 'main', workMode: 'code', disabledAgentTools: [],
  cancellation: { isCancelled, reason: () => 'paused' } });
test('native executor keeps validation, semantic normalization, guard and handler ordering', async () => {
  const steps = [];
  const definition = { ...getToolDefinition('read_file'),
    validateInput: input => { steps.push('semantic'); return { success: true, value: { ...input, path: 'normalized' } }; },
    handler: async (_, input) => { steps.push(input.path); return { output: { success: true } }; }
  };
  const guards = [request => { steps.push('guard'); assert.equal(request.input.path, 'normalized'); }];
  assert.equal((await executeAgentToolDefinition(definition, {}, context(), schemaContext, guards)).output.code, 'INVALID_TOOL_INPUT');
  assert.deepEqual(steps, []);
  assert.equal((await executeAgentToolDefinition(definition, { path: 'a' }, context(), schemaContext, guards)).output.success, true);
  assert.deepEqual(steps, ['semantic', 'guard', 'normalized']);
  const disabled = { ...context(), disabledAgentTools: ['read_file'] };
  assert.equal((await executeAgentToolDefinition(definition, { path: 'a' }, disabled, schemaContext)).output.code, 'TOOL_DISABLED');
});
test('native executor reports cancellation, missing handlers, exceptions and invalid output', async () => {
  const base = getToolDefinition('read_file');
  const run = (definition, ctx = context()) => executeAgentToolDefinition(definition, { path: 'a' }, ctx, schemaContext);
  assert.equal((await run(base)).output.code, 'TOOL_HANDLER_MISSING');
  assert.equal((await run(base, context(() => true))).output.code, 'TOOL_CANCELLED');
  assert.equal((await run({ ...base, handler: async () => { throw new Error('failure'); } })).output.code, 'TOOL_EXECUTION_FAILED');
  assert.equal((await run({ ...base, handler: async () => ({ output: { success: 'yes' } }) })).output.code, 'INVALID_TOOL_OUTPUT');
  let cancelled = false;
  assert.equal((await run({ ...base, handler: async () => { cancelled = true; return { output: { success: true } }; } }, context(() => cancelled))).output.code, 'TOOL_CANCELLED');
  assert.equal((await executeRegisteredAgentTool({ tool: 'unknown', input: {}, context: context(), schemaContext })).output.code, 'UNKNOWN_TOOL');
});
