import test from 'node:test';
import assert from 'node:assert/strict';
import {createAgentLaunchStore} from '../apps/server/agent-launch-store.mjs';
const snapshot=()=>({config:{accountId:'a',projectId:'p',generation:'g'},manifest:{version:1},files:[{path:'init.lua',bytes:Buffer.from('original')}]});
test('launch storage isolates mutations, expires at its deadline and supports revocation',()=>{
  let clock=100;const store=createAgentLaunchStore({now:()=>clock});
  const source=snapshot(),launch=store.put(source,10);
  source.config.accountId='changed';source.files[0].bytes.fill(0);
  const first=store.get(launch.id);assert.equal(first.config.accountId,'a');assert.equal(Buffer.from(first.files[0].bytes).toString(),'original');
  first.config.projectId='changed';first.files[0].bytes.fill(0);
  assert.equal(store.get(launch.id).config.projectId,'p');
  clock=109;assert.ok(store.get(launch.id));clock=110;assert.equal(store.get(launch.id),undefined);
  assert.deepEqual(store.stats(),{entries:0,bytes:0});
  const another=store.put(snapshot());assert.notEqual(another.id,launch.id);
  assert.equal(store.revoke(another.id),true);assert.equal(store.revoke(another.id),false);
  assert.equal(store.get(another.id),undefined);
});
test('launch capacity fails without evicting live work and is reclaimed after expiry',()=>{
  let clock=0;const store=createAgentLaunchStore({maxEntries:1,now:()=>clock});
  const first=store.put(snapshot(),1);assert.throws(()=>store.put(snapshot()),/capacity/);assert.ok(store.get(first.id));
  clock=1;assert.ok(store.put(snapshot()).id);
  assert.throws(()=>createAgentLaunchStore({maxBytes:1}).put(snapshot()),/limit/);
  assert.throws(()=>store.put(snapshot(),0),/lifetime/);
});
test('authenticated renewal extends a live lease but never resurrects expiry or exceeds one day',()=>{
  let clock=100;const store=createAgentLaunchStore({now:()=>clock}),launch=store.put(snapshot(),10);
  clock=105;assert.deepEqual(store.renew(launch.id,10),{expiresAt:115});
  clock=110;assert.ok(store.get(launch.id));
  clock=115;assert.equal(store.renew(launch.id,10),undefined);assert.equal(store.get(launch.id),undefined);
  const day=store.put(snapshot(),24*60*60*1000);
  clock=day.expiresAt-1;assert.deepEqual(store.renew(day.id,1000),{expiresAt:day.expiresAt});
  clock=day.expiresAt;assert.equal(store.renew(day.id,1000),undefined);
});
