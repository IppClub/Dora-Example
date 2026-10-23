import test from 'node:test';
import assert from 'node:assert/strict';
import { createSnapshotReadBackend } from '../packages/agent-contracts/dist/snapshot-read.js';
import { createReadHandler } from '../packages/agent-contracts/dist/read-handler.js';
import { validateReadFile } from '../packages/agent-contracts/dist/read-validation.js';
import { getToolDefinition } from '../packages/agent-contracts/dist/index.js';
import { executeAgentToolDefinition } from '../packages/agent-contracts/dist/executor.js';

test('Agent reads actual immutable snapshot text with original line formatting and identity checks', async () => {
  const snapshot = { version: 1, projectId: 'project-A', revision: 0, entry: 'main.ts', files: [
    { path: 'main.ts', kind: 'text', text: 'one\ntwo\nthree' },
    { path: 'image.bin', kind: 'binary', bytes: new Uint8Array([255]) }
  ] };
  const backend = createSnapshotReadBackend(snapshot);
  snapshot.files[0].text = 'changed';
  assert.equal(backend('project-A', '../main.ts').success, false);
  assert.equal(backend('project-B', 'main.ts').success, false);
  assert.equal(backend('project-A', 'image.bin').success, false);
  const definition = { ...getToolDefinition('read_file'), validateInput: validateReadFile, handler: createReadHandler(backend) };
  const context = { role: 'main', workMode: 'code', disabledAgentTools: [], workingDir: 'project-A', workflow: {},
    cancellation: { isCancelled: () => false, reason: () => undefined } };
  const result = await executeAgentToolDefinition(definition, { path: './main.ts', startLine: -2 }, context, { searchDoraDocLimitMax: 20 });
  assert.equal(result.output.success, true);
  assert.equal(result.output.content, 'two\nthree\n\n(Showing lines 2-3 of 3.)');
  assert.equal(result.output.totalLines, 3);
});
test('virtual documents and logs use exact immutable bindings and cannot fall back to project spoofing', () => {
  const snapshot = { version: 1, projectId: 'A', revision: 0, entry: 'main.lua', files: [
    { path: 'main.lua', kind: 'text', text: '' },
    { path: '@dora_full_logs.txt', kind: 'text', text: 'spoofed' }
  ] };
  const bindings = [{ path: '@dora-doc/en/Node.md', text: 'Node documentation' }, { path: '@dora_full_logs.txt', text: 'run line 1\nrun line 2' }];
  const read = createSnapshotReadBackend(snapshot, bindings);
  bindings[0].text = 'mutated';
  assert.match(read('A', '@dora-doc/en/Node.md').content, /^Node documentation/);
  assert.match(read('A', '@dora_full_logs.txt', -1).content, /^run line 2/);
  assert.equal(read('B', '@dora_full_logs.txt').success, false);
  assert.equal(read('A', './@dora_full_logs.txt').success, false);
  assert.equal(read('A', '@dora-doc/en/../private').success, false);
  assert.equal(createSnapshotReadBackend(snapshot)('A', '@dora_full_logs.txt').success, false);
  assert.throws(() => createSnapshotReadBackend(snapshot, [{ path: '/etc/passwd', text: '' }]));
  assert.throws(() => createSnapshotReadBackend(snapshot, [bindings[0], bindings[0]]));
});


test('snapshot reads resolve omitted ends from the starting line for files and virtual documents', () => {
  const text = Array.from({ length: 1000 }, (_, i) => `line ${i + 1}`).join('\n');
  const read = createSnapshotReadBackend({ version: 1, projectId: 'A', revision: 0, entry: 'main.ts', files: [
    { path: 'main.ts', kind: 'text', text }
  ] }, [{ path: '@dora_full_logs.txt', text }]);
  for (const path of ['main.ts', '@dora_full_logs.txt']) {
    for (const [start, end] of [[1, 300], [400, 699], [-400, 900], [-2, 1000]]) {
      const result = read('A', path, start);
      assert.equal(result.success, true);
      assert.equal(result.endLine, end);
      assert.equal(result.startLine, start > 0 ? start : 1001 + start);
    }
    assert.equal(read('A', path, 400, -1).endLine, 1000);
    assert.equal(read('A', path, 400, 450).endLine, 450);
    assert.equal(read('A', path, 0).success, false);
    assert.equal(read('A', path, 400, 0).success, false);
  }
});
