import test from 'node:test';
import assert from 'node:assert/strict';
import {decideModelAdmission as decide} from '../apps/server/model-admission.mjs';
const fixture=()=>({api:{enabled:true,limit:3,active:0},account:{enabled:true,limit:2,active:0},grant:{enabled:true,limit:1,active:0},reservation:10n,amounts:{accountLimit:100n,accountSpent:0n,accountReserved:0n,grantLimit:50n,grantSpent:0n,grantReserved:0n}});
test('all three concurrent-request scopes must have available capacity',()=>{
 assert.deepEqual(decide(fixture()),{state:'admitted',reservation:10n});
 for(const scope of ['api','account','grant']){
  const input=fixture();input[scope].active=input[scope].limit;
  assert.deepEqual(decide(input),{state:'queued',reason:'concurrency',saturated:[scope]});
 }
 const all=fixture();for(const scope of ['api','account','grant'])all[scope].active=99;
 assert.deepEqual(decide(all).saturated,['api','account','grant']);
});
test('queued requests must be rechecked for revocation, cancellation and amount changes',()=>{
 const input=fixture();input.api.active=3;assert.equal(decide(input).state,'queued');
 input.api.active=0;input.grant.enabled=false;assert.equal(decide(input).reason,'unavailable');
 input.grant.enabled=true;input.cancelled=true;assert.equal(decide(input).reason,'cancelled');
 input.cancelled=false;input.amounts.grantReserved=45n;
 assert.deepEqual(decide(input),{state:'denied',reason:'insufficient-amount',available:5n});
});
test('zero capacity and malformed counters never dispatch',()=>{
 const input=fixture();input.grant.limit=0;assert.equal(decide(input).reason,'zero-capacity');
 input.grant.limit=1;input.api.active=-1;assert.throws(()=>decide(input));
 input.api.active=0;input.reservation=10;assert.throws(()=>decide(input));
});
