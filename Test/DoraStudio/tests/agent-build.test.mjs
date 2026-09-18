import test from 'node:test';
import assert from 'node:assert/strict';
import { validateBuild, createBuildHandler } from '../packages/agent-contracts/dist/build-tool.js';

test('original build semantics preserve ordered mixed targets and reject empty inputs', () => {
  assert.deepEqual(validateBuild({ path: ' first ', paths: [' second ', '.'] }).value.paths, ['first', 'second', '.']);
  for (const input of [{}, { paths: [] }, { paths: [' '] }, { path: '' }]) assert.equal(validateBuild(input).success, false);
});
test('original build handler preserves partial failure and repair workflow', async () => {
  const calls = [];
  const handler = createBuildHandler(async request => {
    calls.push(request.path);
    return request.path === 'bad' ? { success: false, messages: [{ success: false, file: 'bad.ts' }] } : { success: true };
  });
  const workflow = { unbuiltEdits: true, editsSinceBuild: 2, freshProjectBuildPending: true };
  const result = await handler({ workingDir: 'A', workflow, cancellation: { isCancelled: () => false } }, { paths: ['good', 'bad', 'last'] });
  assert.deepEqual(calls, ['good', 'bad', 'last']);
  assert.equal(result.output.partial, true);
  assert.equal(result.output.failedBuildCount, 1);
  assert.equal(workflow.buildRepairPending, true);
  assert.equal(workflow.lastBuildSucceeded, false);
  assert.equal(workflow.freshProjectBuildPending, true);
});
test('original build handler stops dispatch after cancellation and clears repair state on success', async () => {
  let cancelled = false, calls = 0;
  const handler = createBuildHandler(async () => { calls++; cancelled = true; return { success: true }; });
  const result = await handler({ workingDir: 'A', workflow: {}, cancellation: { isCancelled: () => cancelled } }, { paths: ['first', 'second'] });
  assert.equal(calls, 1);
  assert.equal(result.output.skippedBuildCount, 1);
  const workflow = { freshProjectBuildPending: true, failedTestNeedsBuild: true, failedTestHasSourceEdit: true };
  await createBuildHandler(async () => ({ success: true }))({ workingDir: 'A', workflow, cancellation: { isCancelled: () => false } }, { paths: ['.'] });
  assert.equal(workflow.freshProjectBuildPending, false);
  assert.equal(workflow.failedTestNeedsBuild, false);
});
