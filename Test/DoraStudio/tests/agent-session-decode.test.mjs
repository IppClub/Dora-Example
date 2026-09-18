import test from 'node:test';
import assert from 'node:assert/strict';
import {build} from 'esbuild';
const bundle=await build({entryPoints:['apps/web/src/agent-session-decode.ts'],bundle:true,write:false,format:'esm',platform:'node'});
const {decodeAgentSessionPatch:decode,decodeAgentSessionSnapshot}=await import('data:text/javascript;base64,'+Buffer.from(bundle.outputFiles[0].text).toString('base64'));
const encode=fields=>JSON.stringify({name:'AgentSessionPatch',sessionId:1,...fields});
test('decoder normalizes Lua empty objects and preserves declared clearing values',()=>{
  assert.deepEqual(decode(encode({metrics:[],pendingQuestionnaire:false,hasActivePlan:false,removedStepIds:[]})),{name:'AgentSessionPatch',sessionId:1,metrics:{},pendingQuestionnaire:false,hasActivePlan:false,removedStepIds:[]});
});
test('decoder rejects incomplete entities, invalid enums and unsafe bindings',()=>{
  for(const fields of [{sessionId:1.5},{sessionId:0},{step:{id:1}},{message:{id:1,sessionId:1,role:'system',content:'x',createdAt:1,updatedAt:1}},{metrics:[1]},{removedStepIds:[-1]},{pendingQuestionnaire:true}])assert.throws(()=>decode(encode(fields)));
});
test('decoder bounds depth, bytes and non-finite JSON numbers even in extension fields',()=>{
  assert.throws(()=>decode('{"name":"AgentSessionPatch","sessionId":1,"extra":1e999}'));
  assert.throws(()=>decode(encode({extra:'中'.repeat(400000)})));
  let extra={};for(let i=0;i<70;i++)extra={nested:extra};
  assert.throws(()=>decode(encode({extra})));
});

test('full snapshot validates the original success shape and normalizes optional native fields',()=>{
  const detail={success:true,session:{id:1,projectRoot:'/game',title:'test',kind:'main',rootSessionId:1,memoryScope:'main',workMode:'code',status:'IDLE',createdAt:1,updatedAt:1},messages:[],steps:[],relatedSessions:[],hasActivePlan:false,hasEarlierMessages:true};
  const result=decodeAgentSessionSnapshot(JSON.stringify(detail),1);
  assert.deepEqual(result.checkpoints,[]);
  assert.equal(result.pendingQuestionnaire,null);
  assert.equal(result.hasEarlierMessages,true);
  assert.throws(()=>decodeAgentSessionSnapshot(JSON.stringify(detail),2));
  assert.throws(()=>decodeAgentSessionSnapshot(JSON.stringify({...detail,messages:[{id:1}]}),1));
  assert.throws(()=>decodeAgentSessionSnapshot(JSON.stringify({success:false,message:'missing'}),1),/unavailable/);
});
