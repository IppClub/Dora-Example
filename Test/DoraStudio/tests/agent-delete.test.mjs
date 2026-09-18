import test from 'node:test';
import assert from 'node:assert/strict';
import { createDeleteHandler } from '../packages/agent-contracts/dist/delete-handler.js';
import { validateDeleteFile } from '../packages/agent-contracts/dist/delete-validation.js';
import { getToolDefinition } from '../packages/agent-contracts/dist/index.js';
import { executeAgentToolDefinition } from '../packages/agent-contracts/dist/executor.js';

test('original delete tool protects Agent documents and waits for backend success', async () => {
  let calls = 0;
  const workflow = {};
  const definition = { ...getToolDefinition('delete_file'), validateInput: validateDeleteFile,
    handler: createDeleteHandler({ deleteFile: async () => { calls++; return { success: true, checkpointed: true, reversible: true, binary: false, checkpointId: 1, checkpointSeq: 2 }; } }) };
  const context = { role: 'main', workMode: 'code', taskId: 1, workingDir: 'A', workflow, disabledAgentTools: [], cancellation: { isCancelled: () => false, reason: () => undefined } };
  const run = path => executeAgentToolDefinition(definition, { target_file: path }, context, { searchDoraDocLimitMax: 20 });
  assert.equal((await run(' ')).output.code, 'INVALID_TOOL_INPUT');
  assert.equal((await run('.agent/plan/PLAN.md')).output.code, 'PROTECTED_AGENT_DOCUMENT');
  assert.equal((await run('.agent/main/memory.md')).output.code, 'PROTECTED_AGENT_MEMORY');
  assert.equal(calls, 0);
  const result = await run(' unused.lua ');
  assert.equal(result.output.reversible, true);
  assert.equal(result.output.checkpointId, 1);
  assert.equal(workflow.editsSinceBuild, 1);
  assert.deepEqual(workflow.editedPathsSinceBuild, ['unused.lua']);
});
