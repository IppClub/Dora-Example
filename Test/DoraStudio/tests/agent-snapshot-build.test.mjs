import test from 'node:test';
import assert from 'node:assert/strict';
import { createSnapshotBuildBackend } from '../packages/agent-contracts/dist/snapshot-build.js';

const project = () => ({ version: 1, projectId: 'A', revision: 3, entry: 'main.ts', files: [
  { path: 'main.ts', kind: 'text', text: 'source' },
  { path: 'nested/a.lua', kind: 'text', text: 'return 1' },
  { path: 'nested/deeper/b.yue', kind: 'text', text: 'print 1' },
  { path: 'nested/types.d.ts', kind: 'text', text: '' },
  { path: 'nested/image.bin', kind: 'binary', bytes: new Uint8Array([255]) },
] });

test('snapshot build binds project/revision and traverses only the selected directory', async () => {
  const input = project(), calls = [];
  const build = createSnapshotBuildBackend(input, async request => {
    calls.push({ path: request.path, revision: request.snapshot.revision, text: request.snapshot.files[0].text });
    request.snapshot.files[0].text = 'callback mutation';
    return { success: true };
  });
  input.revision = 9; input.files[0].text = 'caller mutation';
  const result = await build({ workDir: 'A', path: './nested/' });
  assert.equal(result.total, 2);
  assert.deepEqual(calls, [
    { path: 'nested/a.lua', revision: 3, text: 'source' },
    { path: 'nested/deeper/b.yue', revision: 3, text: 'source' },
  ]);
  for (const path of ['/', '/main.ts', '../main.ts', 'nested/../main.ts', '@dora-doc/a.ts', 'C:\\main.ts']) {
    assert.equal((await build({ workDir: 'A', path })).success, false);
  }
  assert.equal((await build({ workDir: 'B', path: '.' })).success, false);
  assert.equal(calls.length, 2);
});

test('snapshot build preserves compiler failure and rejects late success after cancellation', async () => {
  let cancelled = false;
  const build = createSnapshotBuildBackend(project(), async () => { cancelled = true; return { success: true }; });
  const result = await build({ workDir: 'A', path: 'nested/a.lua', isCancelled: () => cancelled });
  assert.equal(result.success, false);
  assert.equal(result.interrupted, true);
  const failed = createSnapshotBuildBackend(project(), async () => { throw new Error('unsupported compiler'); });
  assert.equal((await failed({ workDir: 'A', path: 'nested/deeper/b.yue' })).messages[0].message, 'unsupported compiler');
});

test('snapshot directory build follows original source precedence and skips generated Lua siblings',async()=>{
  const input=project();
  input.files.push({path:'main.lua',kind:'text',text:'generated'},{path:'nested/deeper/b.lua',kind:'text',text:'generated'});
  const calls=[];
  const build=createSnapshotBuildBackend(input,async request=>{calls.push(request.path);return {success:true};});
  const result=await build({workDir:'A',path:'.'});
  assert.equal(result.success,true);
  assert.deepEqual(calls,['main.ts','nested/a.lua','nested/deeper/b.yue']);
});
