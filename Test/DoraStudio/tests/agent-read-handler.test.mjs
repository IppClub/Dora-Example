import test from 'node:test';
import assert from 'node:assert/strict';
import { createReadHandler } from '../packages/agent-contracts/dist/read-handler.js';
import { validateReadFile } from '../packages/agent-contracts/dist/read-validation.js';
import { getToolDefinition } from '../packages/agent-contracts/dist/index.js';
import { executeAgentToolDefinition } from '../packages/agent-contracts/dist/executor.js';

test('original read handler preserves partial batches and post-compression clipping', async () => {
  const calls = [];
  const handler = createReadHandler((...args) => {
    calls.push(args);
    return args[1] === 'missing' ? { success: false, message: 'not found' } : { success: true, content: 'fixture' };
  });
  const definition = { ...getToolDefinition('read_file'), validateInput: validateReadFile, handler };
  const context = { role: 'main', workMode: 'code', disabledAgentTools: [], workingDir: 'project-A',
    useChineseResponse: true, workflow: { resumeNarrowReadMode: true },
    cancellation: { isCancelled: () => false, reason: () => undefined } };
  const result = await executeAgentToolDefinition(definition, { reads: [{ path: 'a' }, { path: 'missing' }, { path: 'b', startLine: -2 }] }, context, { searchDoraDocLimitMax: 20 });
  assert.equal(result.output.success, false);
  assert.equal(result.output.partial, true);
  assert.equal(result.output.succeededReadCount, 2);
  assert.equal(result.output.failedReadCount, 1);
  assert.deepEqual(calls, [['project-A', 'a', 1, 160, 'zh'], ['project-A', 'missing', 1, 160, 'zh'], ['project-A', 'b', -2, -1, 'zh']]);
  assert.equal(result.output.results[0].clipped, true);
  assert.equal(result.output.results[1].clipped, undefined);
  assert.equal(result.output.results[2].clipped, undefined);
  const other = createReadHandler(() => ({ success: true, content: 'separate' }));
  assert.equal((await other({ ...context, workflow: {} }, { path: 'a' })).output.content, 'separate');
  assert.equal(calls.length, 3, 'each handler keeps its own host binding');
});
