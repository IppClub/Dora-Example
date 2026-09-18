import test from 'node:test';
import assert from 'node:assert/strict';
import {build} from 'esbuild';
const bundle=await build({entryPoints:['apps/web/src/agent-session-feed.ts'],bundle:true,write:false,format:'esm',platform:'node'});
const {createAgentSessionFeed}=await import('data:text/javascript;base64,'+Buffer.from(bundle.outputFiles[0].text).toString('base64'));
const event=(sequence,overrides={})=>({version:1,projectId:'p',generation:'g',sessionId:1,sequence,payload:JSON.stringify({name:'AgentSessionPatch',sessionId:1,status:'RUNNING'}),...overrides});
test('session feed ignores foreign bindings and repeated events',()=>{
  const feed=createAgentSessionFeed('p','g',1);
  for(const override of [{projectId:'other'},{generation:'old'},{sessionId:2},{version:2}]) assert.equal(feed.receive(event(1,override)).status,'ignored');
  assert.equal(feed.receive(event(1)).status,'accepted');
  assert.equal(feed.receive(event(1)).status,'ignored');
  assert.equal(feed.sequence,1);
});
test('a gap requires a full resync, not later patches or a delayed missing event',()=>{
  const feed=createAgentSessionFeed('p','g',1);
  assert.equal(feed.receive(event(2)).status,'resync-required');
  assert.equal(feed.receive(event(1)).status,'resync-required');
  assert.equal(feed.sequence,0);
  const resumed=createAgentSessionFeed('p','g',1,2);
  assert.equal(resumed.receive(event(3)).status,'accepted');
});
test('malformed or oversized bound payloads require resync',()=>{
  for(const payload of ['{','[]',JSON.stringify({name:'AgentSessionPatch',sessionId:2}),'中'.repeat(400000)]) {
    const feed=createAgentSessionFeed('p','g',1);
    assert.equal(feed.receive(event(1,{payload})).status,'resync-required');
    assert.equal(feed.sequence,0);
  }
});
