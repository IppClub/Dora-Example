import test from 'node:test';
import assert from 'node:assert/strict';
import {build} from 'esbuild';
const built=await build({entryPoints:['apps/web/src/agent-retirement.ts'],bundle:true,write:false,format:'esm',platform:'node'});
const {createAgentRetirement:create}=await import('data:text/javascript;base64,'+Buffer.from(built.outputFiles[0].text).toString('base64'));
test('retirement retries the failed stage without repeating confirmed save or cleanup',async()=>{
  let saves=0,revokes=0,saveFails=true,revokeFails=true;
  const owner=create({persistAndClose:async()=>{saves++;if(saveFails)throw Error('save failed');},revoke:async()=>{revokes++;if(revokeFails)throw Error('cleanup failed');}});
  await assert.rejects(owner.run());assert.equal(owner.getSnapshot().phase,'save-failed');assert.equal(revokes,0);
  saveFails=false;await assert.rejects(owner.run());assert.equal(owner.getSnapshot().phase,'cleanup-failed');assert.equal(saves,2);
  revokeFails=false;await owner.run();assert.equal(owner.getSnapshot().phase,'closed');assert.equal(saves,2);assert.equal(revokes,2);
  await owner.run();assert.equal(revokes,2);
});
test('retirement coalesces concurrent and reentrant calls',async()=>{
  let release,saves=0;const gate=new Promise(resolve=>{release=resolve;});
  const owner=create({persistAndClose:async()=>{saves++;await gate;},revoke:async()=>{}});
  let reentrant;owner.subscribe(()=>{reentrant=owner.run();});
  const first=owner.run();assert.equal(owner.run(),first);await Promise.resolve();assert.equal(reentrant,first);
  release();await first;assert.equal(saves,1);
});
