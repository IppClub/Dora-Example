import test from 'node:test';
import assert from 'node:assert/strict';
import {build} from 'esbuild';
const bundle=await build({stdin:{contents:"export * from './agent-session-feed'; export * from './agent-session-publisher';",resolveDir:process.cwd()+'/apps/web/src',loader:'ts'},bundle:true,write:false,format:'esm',platform:'node'});
const {createAgentSessionPublisher,createAgentSessionFeed}=await import('data:text/javascript;base64,'+Buffer.from(bundle.outputFiles[0].text).toString('base64'));
const payload=JSON.stringify({name:'AgentSessionPatch',sessionId:1,status:'RUNNING'});
test('publisher and feed agree on contiguous event IDs from a snapshot cursor',()=>{
  const feed=createAgentSessionFeed('p','g',1,9),received=[];
  const publisher=createAgentSessionPublisher('p','g',1,event=>received.push(feed.receive(event)),9);
  assert.equal(publisher.publish(payload),10);assert.equal(publisher.publish(payload),11);
  assert.deepEqual(received.map(item=>item.status),['accepted','accepted']);
  publisher.close();publisher.close();
  assert.throws(()=>publisher.publish(payload),/retired/);
});
test('delivery failure retires publisher and never retries an uncertain event',()=>{
  let calls=0;
  const publisher=createAgentSessionPublisher('p','g',1,()=>{calls++;throw new Error('transport failed');});
  assert.throws(()=>publisher.publish(payload),/transport failed/);
  assert.equal(publisher.sequence,1);assert.equal(publisher.active,false);
  assert.throws(()=>publisher.publish(payload),/retired/);assert.equal(calls,1);
});
test('malformed bound patch never reaches transport',()=>{
  const publisher=createAgentSessionPublisher('p','g',1,()=>assert.fail('Unexpected transport'));
  assert.throws(()=>publisher.publish('{}'),/resync/);
  assert.equal(publisher.active,false);
});
test('reentrant publication cannot hide retirement by catching its own error',()=>{
  const publisher=createAgentSessionPublisher('p','g',1,()=>{
    assert.throws(()=>publisher.publish(payload),/Reentrant/);
  });
  assert.throws(()=>publisher.publish(payload),/retired during delivery/);
  assert.equal(publisher.active,false);
});
