import test from 'node:test';
import assert from 'node:assert/strict';
import {reserveModelRequest as reserve,finishModelRequest as finish,markModelRequestDispatched as dispatch,cancelUndispatchedModelRequest as cancel} from '../apps/server/model-reservation.mjs';
const rates={inputNanoCnyPerMillion:1000000n,outputNanoCnyPerMillion:2000000n};
const fixture=()=>({api:{enabled:true,limit:2,active:0},account:{enabled:true,limit:2,active:0},grant:{enabled:true,limit:2,active:0},reservation:10n,amounts:{accountLimit:100n,accountSpent:0n,accountReserved:0n,grantLimit:50n,grantSpent:0n,grantReserved:0n}});
test('reservation occupies every scope without modifying inputs and pins rates',()=>{
 const input=fixture(),pricing={...rates},result=reserve(input,pricing);
 assert.equal(result.next.api.active,1);assert.equal(result.next.account.active,1);assert.equal(result.next.grant.active,1);
 assert.equal(result.next.amounts.accountReserved,10n);assert.equal(result.next.amounts.grantReserved,10n);
 assert.equal(input.api.active,0);pricing.inputNanoCnyPerMillion=99n;
 assert.equal(result.request.rates.inputNanoCnyPerMillion,1000000n);
 const denied=fixture();denied.api.enabled=false;assert.deepEqual(reserve(denied,rates),{decision:{state:'denied',reason:'unavailable'}});
});
test('missing usage releases concurrency but holds funds until later reconciliation',()=>{
 const start=reserve(fixture(),rates),pending=finish(start.next,dispatch(start.request,start.next),null);
 assert.equal(pending.next.api.active,0);assert.equal(pending.next.amounts.accountReserved,10n);
 assert.equal(pending.request.state,'pending-usage');
 const done=finish(pending.next,pending.request,{inputTokens:2n,outputTokens:1n});
 assert.equal(done.next.api.active,0);assert.equal(done.next.amounts.accountReserved,0n);assert.equal(done.next.amounts.grantReserved,0n);
 assert.equal(done.next.amounts.accountSpent,4n);assert.equal(done.next.amounts.grantSpent,4n);
 assert.throws(()=>finish(done.next,done.request,{inputTokens:2n,outputTokens:1n}),/settleable/);
});
test('settlement records overage after revocation and rejects broken reservation invariants',()=>{
 const start=reserve(fixture(),rates),sent=dispatch(start.request,start.next);start.next.grant.enabled=false;
 const done=finish(start.next,sent,{inputTokens:20n,outputTokens:0n});
 assert.equal(done.request.settlement.overage,10n);assert.equal(done.next.amounts.accountSpent,20n);
 const broken=structuredClone(start.next);broken.amounts.grantReserved=0n;
 assert.throws(()=>finish(broken,sent,null),/reserved/);
 assert.equal(start.next.api.active,1);
});
test('only a durably undispatched reservation can release funds without usage',()=>{
 const start=reserve(fixture(),rates);
 assert.equal(start.request.state,'reserved');
 assert.throws(()=>finish(start.next,start.request,null),/settleable/);
 const cancelled=cancel(start.next,start.request);
 assert.equal(cancelled.request.state,'cancelled-before-dispatch');
 assert.equal(cancelled.next.api.active,0);assert.equal(cancelled.next.account.active,0);assert.equal(cancelled.next.grant.active,0);
 assert.equal(cancelled.next.amounts.accountReserved,0n);assert.equal(cancelled.next.amounts.grantReserved,0n);assert.equal(cancelled.next.amounts.accountSpent,0n);
 const sent=dispatch(start.request,start.next);
 assert.throws(()=>cancel(start.next,sent),/dispatched/);
 assert.throws(()=>dispatch(sent),/reserved/);
 const uncertain=finish(start.next,sent,null);
 assert.equal(uncertain.next.amounts.accountReserved,10n);
 assert.equal(start.request.state,'reserved');
});
test('dispatch rechecks revocation, cancellation, reduced limits and funds without double reservation',()=>{
 const start=reserve(fixture(),rates),before=structuredClone(start.next);
 // Exactly one permitted slot and exactly the reserved amount remain valid.
 const exact=structuredClone(start.next);
 for(const scope of ['api','account','grant'])exact[scope].limit=1;
 exact.amounts.accountLimit=10n;exact.amounts.grantLimit=10n;
 assert.equal(dispatch(start.request,exact).state,'in-flight');
 for(const scope of ['api','account','grant']){
  const revoked=structuredClone(start.next);revoked[scope].enabled=false;
  assert.throws(()=>dispatch(start.request,revoked),/unavailable/);
  const reduced=structuredClone(start.next);reduced[scope].active=2;reduced[scope].limit=1;
  assert.throws(()=>dispatch(start.request,reduced),/concurrency/);
  const missing=structuredClone(start.next);missing[scope].active=0;
  assert.throws(()=>dispatch(start.request,missing),/Missing active/);
 }
 for(const scope of ['account','grant']){
  const reduced=structuredClone(start.next);reduced.amounts[`${scope}Limit`]=9n;
  assert.throws(()=>dispatch(start.request,reduced),/insufficient-amount/);
  const missing=structuredClone(start.next);missing.amounts[`${scope}Reserved`]=9n;
  assert.throws(()=>dispatch(start.request,missing),/Missing reserved/);
 }
 assert.throws(()=>dispatch(start.request,{...start.next,cancelled:true}),/cancelled/);
 assert.throws(()=>dispatch(start.request),TypeError);
 assert.deepEqual(start.next,before);assert.equal(start.request.state,'reserved');
 // A refused dispatch has no side effects; its durable reservation can be cancelled.
 assert.equal(cancel(start.next,start.request).next.amounts.accountReserved,0n);
});
