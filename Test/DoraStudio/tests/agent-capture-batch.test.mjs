import test from 'node:test';
import assert from 'node:assert/strict';
import {build} from 'esbuild';
const built=await build({entryPoints:['apps/web/src/agent-capture-batch.ts'],bundle:true,write:false,format:'esm',platform:'browser'});
const {captureAgentRunBatch}=await import(`data:text/javascript;base64,${Buffer.from(built.outputFiles[0].text).toString('base64')}`);
Object.defineProperty(globalThis,'navigator',{configurable:true,value:{locks:{request:async(_key,_options,callback)=>callback()}}});
const project={name:'P',snapshot:{projectId:'p',revision:0,files:[]}};
test('capture batch validates ownership/times and never redispatches a reserved operation',async()=>{
  let calls=0;
  const storage={async reserveVisionCapture(){calls++;return {replayed:true,result:{success:true,files:['missing'],revision:1}};},async load(){return undefined;},async loadCheckpoint(){return undefined;}};
  const run={projectId:'p',revision:0,runId:'r',capture(){assert.fail('must not dispatch');}};
  for(const times of [[],[1,1],[-1],[11],[NaN],[0,1,2,3]])
    await assert.rejects(captureAgentRunBatch(storage,project,run,1,'op',times,new AbortController().signal));
  await assert.rejects(captureAgentRunBatch(storage,project,{...run,projectId:'other'},1,'op',[0],new AbortController().signal));
  assert.equal(calls,0);
  await assert.rejects(captureAgentRunBatch(storage,project,run,1,'op',[0],new AbortController().signal),/unavailable/);
  assert.equal(calls,1);
});
test('capture batch cancels while awaiting startup without stopping someone else\'s run',async()=>{
  const signal=new AbortController();
  let recorded;
  const storage={async reserveVisionCapture(){return {replayed:false};},async completeVisionCaptureFailure(...args){recorded=args;}};
  const run={projectId:'p',revision:0,runId:'r',ready:new Promise(()=>{}),capture(){assert.fail();},stop(){assert.fail();}};
  const pending=captureAgentRunBatch(storage,project,run,1,'op',[0],signal.signal);
  await new Promise(resolve=>setTimeout(resolve,0));signal.abort();
  const result=await pending;
  assert.equal(result.success,false);assert.equal(result.interrupted,true);
  assert.deepEqual(result.files,[]);assert.equal(result.visionCapture.frameCount,1);
  assert.equal(recorded[0],'p');assert.equal(recorded[2],'op');assert.equal(recorded[5],true);
});
