import test from 'node:test';
import assert from 'node:assert/strict';
import {build} from 'esbuild';

const bundled=await build({entryPoints:['apps/web/src/agent-session-durability.ts'],bundle:true,write:false,format:'esm',platform:'node'});
const {persistSessionBoundariesBeforePublish}=await import(`data:text/javascript;base64,${Buffer.from(bundled.outputFiles[0].text).toString('base64')}`);

const patch=fields=>JSON.stringify({name:'AgentSessionPatch',sessionId:1,...fields});
const running={id:1,projectRoot:'/user/studio-project',title:'test',kind:'main',rootSessionId:1,memoryScope:'main',workMode:'code',status:'RUNNING',currentTaskId:2,currentTaskStatus:'RUNNING',createdAt:1,updatedAt:2};

test('accepted Code task is published and acknowledged only after durable storage',async()=>{
  let emit,release,stored=false;
  const source={capture:async()=>({payload:'snapshot',sequence:0}),subscribe(listener){emit=listener;return()=>{};}};
  const persistence=new Promise(resolve=>{release=()=>{stored=true;resolve();};});
  const durable=persistSessionBoundariesBeforePublish(source,()=>persistence,new AbortController().signal);
  const delivered=[];durable.subscribe((payload,sequence)=>delivered.push({payload,sequence,stored}));
  emit(patch({session:running,message:{id:1,sessionId:1,taskId:2,role:'user',content:'制作游戏',createdAt:1,updatedAt:1}}),1);
  await Promise.resolve();assert.deepEqual(delivered,[]);
  let acknowledged=false;const acknowledgement=durable.waitForDurability().then(()=>{acknowledged=true;});
  await Promise.resolve();assert.equal(acknowledged,false);
  release();await acknowledgement;await new Promise(resolve=>setTimeout(resolve,0));
  assert.equal(delivered.length,1);assert.equal(delivered[0].stored,true);assert.equal(delivered[0].sequence,1);
});

test('questionnaire publication and resumed Plan task are durable boundaries',async()=>{
  let emit,persistCalls=0;
  const source={capture:async()=>({payload:'snapshot',sequence:3}),subscribe(listener){emit=listener;return()=>{};}};
  const durable=persistSessionBoundariesBeforePublish(source,async()=>{persistCalls++;},new AbortController().signal);
  const delivered=[];durable.subscribe((_payload,sequence)=>delivered.push(sequence));
  emit(patch({pendingQuestionnaire:{id:7,sessionId:1,taskId:2,step:3,status:'PENDING',schema:{title:'选择',questions:[]},createdAt:1}}),1);
  emit(patch({session:{...running,workMode:'plan'},pendingQuestionnaire:false}),2);
  await durable.waitForDurability();
  assert.equal(persistCalls,2);assert.deepEqual(delivered,[1,2]);
});

test('ordinary patches retain order without forcing storage and capture waits for a boundary',async()=>{
  let emit,release,persistCalls=0,captures=0;
  const source={capture:async()=>{captures++;return{payload:'snapshot',sequence:2};},subscribe(listener){emit=listener;return()=>{};}};
  const durable=persistSessionBoundariesBeforePublish(source,()=>{persistCalls++;return new Promise(resolve=>{release=resolve;});},new AbortController().signal);
  const delivered=[];durable.subscribe((_payload,sequence)=>delivered.push(sequence));
  emit(patch({hasActivePlan:true}),1);await new Promise(resolve=>setTimeout(resolve,0));
  assert.deepEqual(delivered,[1]);assert.equal(persistCalls,0);
  emit(patch({pendingQuestionnaire:{id:7,sessionId:1,taskId:2,step:3,status:'PENDING',schema:{title:'选择',questions:[]},createdAt:1}}),2);
  const captured=durable.capture(new AbortController().signal);await Promise.resolve();assert.equal(captures,0);
  release();assert.deepEqual(await captured,{payload:'snapshot',sequence:2});assert.equal(captures,1);assert.deepEqual(delivered,[1,2]);
});
