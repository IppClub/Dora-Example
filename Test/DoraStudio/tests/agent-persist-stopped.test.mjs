import test from 'node:test';
import assert from 'node:assert/strict';
import {build} from 'esbuild';
const bundle=await build({entryPoints:['apps/web/src/agent-persist-stopped.ts'],bundle:true,write:false,format:'esm',platform:'node'});
const {persistStoppedAgent:save}=await import('data:text/javascript;base64,'+Buffer.from(bundle.outputFiles[0].text).toString('base64'));
test('persistence follows actual quiescence and requests a fresh sync',async()=>{
  const events=[];let count=0;
  await save({quiesce:async()=>{events.push('poll');return ++count===1?{quiescent:false,pending:[{}]}:{quiescent:true,pending:[]};}},
    {doraSyncUserStorage:async options=>{assert.deepEqual(options,{afterCurrent:true});events.push('sync');}},new AbortController().signal);
  assert.deepEqual(events,['poll','poll','sync']);
});
test('failed storage and stalled task inspection never report persistence success',async()=>{
  await assert.rejects(save({quiesce:async()=>({quiescent:true,pending:[]})},{doraSyncUserStorage:async()=>{throw Error('quota');}},new AbortController().signal),/quota/);
  let synced=false;
  await assert.rejects(save({quiesce:()=>new Promise(()=>{})},{doraSyncUserStorage:async()=>{synced=true;}},new AbortController().signal,20),/timed out/);
  assert.equal(synced,false);
});
test('abort during sync rejects even when the underlying storage later completes',async()=>{
  const abort=new AbortController();let finish;
  const pending=save({quiesce:async()=>({quiescent:true,pending:[]})},{doraSyncUserStorage:()=>new Promise(resolve=>{finish=resolve;abort.abort(Error('cancelled'));})},abort.signal);
  await assert.rejects(pending,/cancelled/);finish();
});
