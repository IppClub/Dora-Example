import test from 'node:test';
import assert from 'node:assert/strict';
import { createEditHandler } from '../packages/agent-contracts/dist/edit-handler.js';

test('native edit handler stages ordered edits, reports partial success and commits once', async () => {
  const files = new Map([['a.lua', 'one']]); let commits = 0;
  const handler = createEditHandler({
    inspectWorkspaceTextTarget: (_, path) => ({ success: true, exists: files.has(path), content: files.get(path) ?? '' }),
    applyFileChanges: (_, workDir, changes) => { commits++; for (const change of changes) files.set(change.path, change.content); return { success: true, checkpointId: 1, checkpointSeq: 1 }; },
    readFileRaw: (_, path) => ({ success: files.has(path), content: files.get(path) })
  });
  const workflow = {};
  const result = await handler({ workingDir: 'A', taskId: 1, workMode: 'code', workflow }, { edits: [
    { path: 'a.lua', old_str: 'one', new_str: 'two' },
    { path: 'a.lua', old_str: 'missing', new_str: 'bad' },
    { path: 'a.lua', old_str: 'two', new_str: 'three' }
  ] });
  assert.equal(commits, 1);
  assert.equal(files.get('a.lua'), 'three');
  assert.equal(result.output.partial, true);
  assert.equal(result.output.actualSaved, true);
  assert.equal(result.output.succeededOperationCount, 2);
  assert.equal(workflow.editsSinceBuild, 2);
});
test('Studio edit adaptation waits for asynchronous commit before readback and workflow updates', async () => {
  let finish;
  const committed = new Promise(resolve => { finish = resolve; });
  let text = 'before', reads = 0, settled = false;
  const workflow = {};
  const handler = createEditHandler({
    inspectWorkspaceTextTarget: () => ({ success: true, exists: true, content: text }),
    applyFileChanges: async () => { await committed; text = 'after'; return { success: true, checkpointId: 3, checkpointSeq: 1 }; },
    readFileRaw: () => { reads++; return { success: true, content: text }; }
  });
  const pending = handler({ workingDir: 'A', taskId: 1, workMode: 'code', workflow }, { path: 'a.lua', old_str: 'before', new_str: 'after' });
  pending.then(() => { settled = true; });
  await Promise.resolve();
  assert.equal(settled, false);
  assert.equal(reads, 0);
  assert.equal(workflow.unbuiltEdits, undefined);
  finish();
  const result = await pending;
  assert.equal(result.output.actualSaved, true);
  assert.equal(reads, 1);
  assert.equal(workflow.unbuiltEdits, true);
});
test('failed asynchronous commit never reports saved or advances edit workflow', async () => {
  const workflow = {};
  const handler = createEditHandler({
    inspectWorkspaceTextTarget: () => ({ success: true, exists: true, content: 'before' }),
    applyFileChanges: async () => ({ success: false, message: 'revision conflict' }),
    readFileRaw: () => { throw new Error('readback must not run'); }
  });
  const result = await handler({ workingDir: 'A', taskId: 1, workMode: 'code', workflow }, { path: 'a.lua', old_str: 'before', new_str: 'after' });
  assert.equal(result.output.success, false);
  assert.equal(result.output.actualSaved, false);
  assert.equal(workflow.unbuiltEdits, undefined);
});
