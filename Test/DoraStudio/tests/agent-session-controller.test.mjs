import test from 'node:test';
import assert from 'node:assert/strict';
import {build} from 'esbuild';
const bundle=await build({entryPoints:['apps/web/src/agent-session-controller.ts'],bundle:true,write:false,format:'esm',platform:'node'});
const {createAgentSessionController:create,openAgentSessionSnapshot:open}=await import('data:text/javascript;base64,'+Buffer.from(bundle.outputFiles[0].text).toString('base64'));
const binding=()=>({projectId:'p',generation:'g',sequence:0,snapshot:{session:{id:1},messages:[],steps:[],checkpoints:[],relatedSessions:[],pendingQuestionnaire:null,spawnInfo:null,hasActivePlan:false}});
const event=(sequence,fields={})=>({version:1,projectId:'p',generation:'g',sessionId:1,sequence,payload:JSON.stringify({name:'AgentSessionPatch',sessionId:1,...fields})});
test('validated events update state once and preserve the last good state after a gap',()=>{
  const controller=create(binding());
  assert.equal(controller.receive(event(1,{hasActivePlan:true})),'updated');
  const last=controller.state;
  assert.equal(last.hasActivePlan,true);
  assert.equal(controller.receive(event(1,{hasActivePlan:false})),'ignored');
  assert.equal(controller.state,last);
  assert.equal(controller.receive(event(3)),'resync-required');
  assert.equal(controller.receive(event(2)),'resync-required');
  assert.equal(controller.state,last);
  assert.equal(controller.sequence,1);
});
test('malformed bound records cannot reach the state reducer',()=>{
  const controller=create(binding()), initial=controller.state;
  assert.equal(controller.receive(event(1,{message:{id:1}})),'resync-required');
  assert.equal(controller.state,initial);
  assert.equal(controller.sequence,0);
});
test('retirement and deletion ignore late events; a new snapshot resumes at its own cursor',()=>{
  const old=create(binding());old.close();
  assert.equal(old.receive(event(1)),'ignored');
  const resumed=create({...binding(),sequence:5});
  assert.equal(resumed.receive(event(6,{sessionDeleted:true})),'updated');
  assert.equal(resumed.closed,true);
  assert.equal(resumed.state.deleted,true);
  assert.equal(resumed.receive(event(7,{hasActivePlan:true})),'ignored');
});

test('React store snapshots are stable until change and notify resync/close only once',()=>{
  const controller=create(binding());
  const initial=controller.getSnapshot();
  assert.equal(controller.getSnapshot(),initial);
  let count=0;
  const unsubscribe=controller.subscribe(()=>count++);
  controller.subscribe(()=>{throw new Error('subscriber failed');});
  controller.receive(event(1,{hasActivePlan:true}));
  assert.equal(count,1);
  assert.notEqual(controller.getSnapshot(),initial);
  controller.receive(event(3));controller.receive(event(4));
  assert.equal(count,2);
  assert.equal(controller.getSnapshot().connection,'resync-required');
  controller.close();controller.close();
  assert.equal(count,3);
  assert.equal(controller.getSnapshot().connection,'closed');
  unsubscribe();
});

test('snapshot handshake validates all expected bindings and starts after the supplied cursor',()=>{
  const expected={projectId:'p',generation:'g',sessionId:1};
  const payload=JSON.stringify({success:true,session:{id:1,projectRoot:'/game',title:'test',kind:'main',rootSessionId:1,memoryScope:'main',workMode:'code',status:'IDLE',createdAt:1,updatedAt:1},messages:[],steps:[],relatedSessions:[],hasActivePlan:false});
  const envelope={version:1,...expected,sequence:7,payload};
  const controller=open(expected,envelope);
  assert.equal(controller.receive(event(7)),'ignored');
  assert.equal(controller.receive(event(8,{hasActivePlan:true})),'updated');
  assert.equal(controller.state.hasActivePlan,true);
  for(const changed of [{projectId:'other'},{generation:'old'},{sessionId:2},{version:2},{sequence:-1},{sequence:1.2},{payload:'{}'}]) assert.throws(()=>open(expected,{...envelope,...changed}));
  assert.equal(expected.generation,'g');
});
