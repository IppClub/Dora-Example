import test from 'node:test';
import assert from 'node:assert/strict';
import {build} from 'esbuild';
const bundle=await build({entryPoints:['apps/web/src/agent-file-changes.ts'],bundle:true,write:false,platform:'node',format:'esm'});
const {saveAgentFileChanges}=await import('data:text/javascript;base64,'+Buffer.from(bundle.outputFiles[0].text).toString('base64'));
const project={name:'Game',createdAt:0,updatedAt:0,snapshot:{version:1,projectId:'p',revision:3,entry:'init.lua',files:[{path:'init.lua',kind:'text',text:'print(1)'},{path:'old.txt',kind:'text',text:'old'}]}};
const batch={projectId:'p',baseRevision:3,writes:[{path:'new.png',kind:'binary',bytes:new Uint8Array([1,2,3])}],deletes:['old.txt']};
test('Agent changes preserve untouched author files and request atomic checkpointed revision',async()=>{
  let received;
  const storage={save:async(...args)=>{received=args;return {...project,snapshot:args[1]};}};
  const result=await saveAgentFileChanges(storage,project,batch,new AbortController().signal);
  assert.equal(result.snapshot.revision,4);
  assert.deepEqual(received.slice(2),[3,true]);
  assert.equal(result.snapshot.files.find(file=>file.path==='init.lua').text,'print(1)');
  assert.ok(!result.snapshot.files.some(file=>file.path==='old.txt'));
  batch.writes[0].bytes[0]=9;
  assert.equal(result.snapshot.files.find(file=>file.path==='new.png').bytes[0],1);
  assert.equal(project.snapshot.revision,3);
});
test('Agent changes reject mismatched, duplicate and cancelled requests before saving',async()=>{
  const storage={save:()=>{throw new Error('Must not save');}};
  await assert.rejects(saveAgentFileChanges(storage,project,{...batch,baseRevision:2},new AbortController().signal),/revision/);
  await assert.rejects(saveAgentFileChanges(storage,project,{...batch,deletes:['old.txt','old.txt']},new AbortController().signal),/duplicate/);
  const abort=new AbortController();abort.abort();
  await assert.rejects(saveAgentFileChanges(storage,project,batch,abort.signal),/abort/i);
});
test('storage revision conflicts propagate without reporting success',async()=>{
  await assert.rejects(saveAgentFileChanges({save:async()=>{throw new Error('revision conflict');}},project,batch,new AbortController().signal),/revision conflict/);
});
