import test from 'node:test';
import assert from 'node:assert/strict';
import {build} from 'esbuild';
const bundle=await build({entryPoints:['../Assets/Script/Lib/Agent/Runtime/FileCommitEvents.ts'],bundle:true,write:false,format:'esm',platform:'node'});
const events=await import('data:text/javascript;base64,'+Buffer.from(bundle.outputFiles[0].text).toString('base64'));
test('file commits deliver one immutable batch only to the exact project',()=>{
 const received=[];
 const stop=events.subscribeFileCommits('/project',payload=>received.push(payload));
 const other=events.subscribeFileCommits('/project-other',()=>assert.fail('foreign project'));
 try{
  const payload=JSON.stringify({checkpointId:5,changes:[{path:'a.lua',op:'write'},{path:'b.lua',op:'delete'}]});
  assert.equal(events.hasFileCommitListeners('/project'),true);
  assert.equal(events.publishFileCommit('/project',payload),0);assert.deepEqual(received,[payload]);
 }finally{stop();stop();other();}
 assert.equal(events.hasFileCommitListeners('/project'),false);
});
test('failed observers do not block other subscribers or change commit notification state',()=>{
 let calls=0;const bad=events.subscribeFileCommits('/p',()=>{throw Error('observer');});
 const good=events.subscribeFileCommits('/p',()=>{calls++;});
 try{assert.equal(events.publishFileCommit('/p','{}'),1);assert.equal(calls,1);}
 finally{bad();good();}
});
