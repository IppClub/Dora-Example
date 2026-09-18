import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {createServer} from 'node:http';
import {once} from 'node:events';
import {DatabaseSync} from 'node:sqlite';
import {openModelLedger} from '../apps/server/model-ledger-sqlite.mjs';
import {openModelConfigurationStore} from '../apps/server/model-configuration-store.mjs';
import {executeModelRequest as execute,settleRecordedModelRequest} from '../apps/server/model-request-executor.mjs';
const intent={requestId:'request',accountId:'account',apiId:'api',grantId:'grant',fingerprint:'trusted-payload-hash',reservation:10n,rates:{inputNanoCnyPerMillion:1000000n,outputNanoCnyPerMillion:2000000n}};
function catalogFor(t,ledger){
 const catalog=openModelConfigurationStore(ledger.testPath,{providerIds:new Set(['fixture'])});
 t.after(()=>catalog.close());
 const put=(enabled,expectedVersion)=>catalog.put({id:'api',kind:'shared',ownerId:'platform',label:'Fixture',model:'fixture',providerId:'fixture',enabled},{expectedVersion,actorId:'admin'});
 put(true,0);return put;
}
function setup(t){
 const dir=mkdtempSync(join(tmpdir(),'studio-model-execute-')),ledger=openModelLedger(join(dir,'ledger.db'));
 ledger.testPath=join(dir,'ledger.db');
 t.after(()=>{ledger.close();rmSync(dir,{recursive:true,force:true});});
 ledger.configure('api','api',{enabled:true,limit:1},{actorId:'admin'});
 ledger.configure('account','account',{enabled:true,limit:1,amountLimit:100n},{actorId:'admin'});
 ledger.configure('grant','grant',{enabled:true,limit:1,amountLimit:100n,accountId:'account',apiId:'api'},{actorId:'admin'});
 return ledger;
}
test('local HTTP completion settles once and repeat calls do not reach transport',async t=>{
 const ledger=setup(t);let calls=0;
 const server=createServer((req,res)=>{
  calls++;assert.equal(ledger.request('request').request.state,'in-flight');
  res.setHeader('Content-Type','application/json');res.end(JSON.stringify({text:'fixture reply',input:2,output:1}));
 });
 server.listen(0,'127.0.0.1');await once(server,'listening');
 t.after(()=>new Promise(resolve=>{server.closeAllConnections();server.close(resolve);}));
 const send=async({signal})=>{
  const data=await fetch(`http://127.0.0.1:${server.address().port}`,{signal}).then(response=>response.json());
  return {completed:true,usage:{inputTokens:BigInt(data.input),outputTokens:BigInt(data.output)},response:data.text};
 };
 const result=await execute({ledger,intent,send});
 assert.equal(result.state,'settled');assert.equal(result.response,'fixture reply');
 assert.equal(ledger.scope('account','account').spent,4n);assert.equal(ledger.scope('api','api').active,0);
 assert.equal((await execute({ledger,intent,send})).state,'existing');assert.equal(calls,1);
});
test('in-flight duplicate and other requests never bypass the held slot',async t=>{
 const ledger=setup(t);let release,calls=0;
 const send=()=>{calls++;return new Promise(resolve=>{release=resolve;});};
 const first=execute({ledger,intent,send});
 assert.equal((await execute({ledger,intent,send})).state,'existing');
 assert.equal((await execute({ledger,intent:{...intent,requestId:'other'},send})).state,'queued');
 assert.equal(calls,1);
 release({completed:true,usage:null,response:'no usage'});
 assert.equal((await first).state,'pending-usage');
 assert.equal(ledger.scope('api','api').active,0);assert.equal(ledger.scope('account','account').reserved,10n);
});
test('uncertain transport failure retains both holds and hides sensitive errors',async t=>{
 const ledger=setup(t);let calls=0;
 const send=async()=>{calls++;throw new Error('secret-url-token');};
 const result=await execute({ledger,intent,send});
 assert.equal(result.state,'needs-reconciliation');assert.equal(result.error,undefined);
 assert.equal(ledger.scope('api','api').active,1);assert.equal(ledger.scope('account','account').reserved,10n);
 assert.equal((await execute({ledger,intent,send})).state,'existing');assert.equal(calls,1);
});
test('cancellation before admission sends nothing, but confirmed late usage is charged',async t=>{
 const ledger=setup(t),controller=new AbortController();controller.abort();
 let calls=0;
 assert.equal((await execute({ledger,intent,signal:controller.signal,send:()=>{calls++;}})).state,'cancelled-before-admission');
 assert.equal(ledger.request('request'),undefined);assert.equal(calls,0);
 const live=new AbortController();
 const result=await execute({ledger,intent,signal:live.signal,send:async()=>{
  live.abort();return {completed:true,usage:{inputTokens:1n,outputTokens:1n}};
 }});
 assert.equal(result.state,'settled');assert.equal(ledger.scope('account','account').spent,3n);
});
test('settlement storage failure cannot publish success or cause resend',async t=>{
 const ledger=setup(t),fault=new DatabaseSync(ledger.testPath);t.after(()=>fault.close());let calls=0;
 const send=async()=>{
  calls++;
  fault.exec("CREATE TRIGGER fail_settlement BEFORE UPDATE ON model_requests WHEN json_extract(NEW.data,'$.request.state')='settled' BEGIN SELECT RAISE(ABORT,'settlement storage failure'); END;");
  return {completed:true,usage:{inputTokens:2n,outputTokens:1n},response:'not committed'};
 };
 await assert.rejects(execute({ledger,intent,send}),/settlement storage failure/);
 assert.equal(ledger.request('request').request.state,'in-flight');
 assert.deepEqual(ledger.request('request').receipt.usage,{inputTokens:2n,outputTokens:1n});
 assert.equal(ledger.scope('account','account').spent,0n);assert.equal(ledger.scope('account','account').reserved,10n);
 fault.exec('DROP TRIGGER fail_settlement');
 assert.equal((await execute({ledger,intent,send})).state,'existing');assert.equal(calls,1);
 const reopened=openModelLedger(ledger.testPath);
 try{
  const settled=settleRecordedModelRequest(reopened,'request');
  assert.equal(settled.request.state,'settled');assert.equal(reopened.scope('account','account').spent,4n);
  assert.throws(()=>settleRecordedModelRequest(reopened,'request'),/No unsettled/);
 }finally{reopened.close();}
 assert.equal(calls,1);
});
test('malformed usage never settles as free consumption',async t=>{
 const ledger=setup(t);
 const result=await execute({ledger,intent,send:async()=>({completed:true,usage:{inputTokens:2,outputTokens:1}})});
 assert.equal(result.state,'needs-reconciliation');
 assert.equal(ledger.scope('api','api').active,1);assert.equal(ledger.scope('account','account').reserved,10n);
 assert.equal(ledger.scope('account','account').spent,0n);
});
test('explicit queued resume shares dispatch/settlement and a competing executor never resends',async t=>{
 const ledger=setup(t),other=openModelLedger(ledger.testPath);t.after(()=>other.close());
 ledger.reserve({...intent,requestId:'occupant',fingerprint:'occupant'});
 let calls=0,release;
 const send=()=>{calls++;return new Promise(resolve=>{release=resolve;});};
 assert.equal((await execute({ledger,intent,send})).state,'queued');
 assert.equal((await execute({ledger,intent,send})).state,'existing');
 assert.equal((await execute({ledger,intent,send,resumeQueued:true})).state,'queued');assert.equal(calls,0);
 ledger.transition('occupant',1,'cancel');
 const winner=execute({ledger,intent,send,resumeQueued:true});
 assert.equal((await execute({ledger:other,intent,send,resumeQueued:true})).state,'existing');assert.equal(calls,1);
 release({completed:true,usage:{inputTokens:2n,outputTokens:1n},response:'resumed'});
 assert.equal((await winner).state,'settled');assert.equal(ledger.scope('account','account').spent,4n);
 assert.equal((await execute({ledger,intent,send,resumeQueued:true})).state,'existing');assert.equal(calls,1);
});
test('queued resume cannot replace the input binding or bypass revoked authorization',async t=>{
 const ledger=setup(t);ledger.reserve({...intent,requestId:'occupant',fingerprint:'occupant'});
 let calls=0;const send=async()=>{calls++;return {completed:true,usage:null};};
 await execute({ledger,intent,send});
 await assert.rejects(execute({ledger,intent:{...intent,fingerprint:'changed prompt'},send,resumeQueued:true}),/binding mismatch/);
 ledger.configure('grant','grant',{enabled:false,limit:1,amountLimit:100n,accountId:'account',apiId:'api'},{actorId:'admin'});
 assert.equal((await execute({ledger,intent,send,resumeQueued:true})).state,'denied');
 assert.equal(ledger.request('request').request.state,'rejected-before-dispatch');assert.equal(calls,0);
 assert.equal(ledger.scope('account','account').reserved,10n);
});

for(const kind of ['api','account','grant'])test(`queued resume rechecks revoked ${kind} after capacity becomes free`,async t=>{
 const ledger=setup(t);
 ledger.reserve({...intent,requestId:'occupant',fingerprint:'occupant'});
 let calls=0;
 const send=async()=>{calls++;return {completed:true,usage:null};};
 assert.equal((await execute({ledger,intent,send})).state,'queued');
 ledger.transition('occupant',1,'cancel');
 ledger.configure(kind,kind,{enabled:false,limit:1,amountLimit:100n,...(kind==='grant'?{accountId:'account',apiId:'api'}:{})},{actorId:'admin'});
 const result=await execute({ledger,intent,send,resumeQueued:true});
 assert.equal(result.state,'denied');
 assert.equal(result.record.request.state,'rejected-before-dispatch');
 assert.equal(calls,0);
 for(const scope of ['api','account','grant'])assert.equal(ledger.scope(scope,scope).active,0);
 for(const scope of ['account','grant']){
  assert.equal(ledger.scope(scope,scope).reserved,0n);
  assert.equal(ledger.scope(scope,scope).spent,0n);
 }
 // Re-enabling an account/configuration does not resurrect a rejected request.
 ledger.configure(kind,kind,{enabled:true,limit:1,amountLimit:100n,...(kind==='grant'?{accountId:'account',apiId:'api'}:{})},{actorId:'admin'});
 assert.equal((await execute({ledger,intent,send,resumeQueued:true})).state,'existing');
 assert.equal(calls,0);
});

test('catalog-bound queue rejects changed configuration without transport or holds',async t=>{
 const ledger=setup(t),put=catalogFor(t,ledger),bound={...intent,configurationVersion:1};
 ledger.reserve({...intent,requestId:'occupant',fingerprint:'occupant'});
 let calls=0;const send=async()=>{calls++;return {completed:true,usage:null};};
 assert.equal((await execute({ledger,intent:bound,send})).state,'queued');
 ledger.transition('occupant',1,'cancel');
 put(true,1); // Even an enabled replacement must not silently change the model binding.
 const result=await execute({ledger,intent:bound,send,resumeQueued:true});
 assert.equal(result.state,'denied');assert.equal(result.decision.reason,'configuration-unavailable');
 assert.equal(ledger.scope('account','account').reserved,0n);assert.equal(calls,0);
 await assert.rejects(execute({ledger,intent:{...bound,configurationVersion:2},send}),/binding mismatch/);
});

test('catalog revocation between reserve and dispatch releases holds and never sends',async t=>{
 const ledger=setup(t),put=catalogFor(t,ledger);let calls=0;
 const wrapped={...ledger,reserve(value){const result=ledger.reserve(value);put(false,1);return result;}};
 const result=await execute({ledger:wrapped,intent:{...intent,configurationVersion:1},send:async()=>{calls++;return {completed:true,usage:null};}});
 assert.equal(result.state,'denied');assert.equal(result.record.request.state,'rejected-before-dispatch');assert.equal(calls,0);
 for(const scope of ['api','account','grant'])assert.equal(ledger.scope(scope,scope).active,0);
 for(const scope of ['account','grant']){assert.equal(ledger.scope(scope,scope).reserved,0n);assert.equal(ledger.scope(scope,scope).spent,0n);}
});

test('catalog-bound admission rejects disabled/missing configuration and settles enabled configuration',async t=>{
 const ledger=setup(t),put=catalogFor(t,ledger);let calls=0;
 const send=async()=>{calls++;return {completed:true,usage:{inputTokens:1n,outputTokens:1n}};};
 put(false,1);
 assert.equal((await execute({ledger,intent:{...intent,configurationVersion:2},send})).state,'denied');
 assert.equal(ledger.request('request'),undefined);
 assert.equal((await execute({ledger,intent:{...intent,apiId:'missing',configurationVersion:1},send})).state,'denied');
 put(true,2);
 assert.equal((await execute({ledger,intent:{...intent,configurationVersion:3},send})).state,'settled');
 assert.equal(calls,1);assert.equal(ledger.scope('account','account').spent,3n);
});

test('strict ledger denies omitted versions while permitting bound model requests',async t=>{
 const legacy=setup(t);catalogFor(t,legacy);
 const ledger=openModelLedger(legacy.testPath,{requireConfigurationVersion:true});t.after(()=>ledger.close());
 let calls=0;const send=async()=>{calls++;return {completed:true,usage:{inputTokens:1n,outputTokens:1n}};};
 assert.equal((await execute({ledger,intent,send})).state,'denied');
 assert.equal(ledger.request('request'),undefined);assert.equal(calls,0);
 assert.equal((await execute({ledger,intent:{...intent,configurationVersion:1},send})).state,'settled');
 assert.equal(calls,1);
 assert.throws(()=>openModelLedger(legacy.testPath,{requireConfigurationVersion:'true'}),/binding policy/);
});

test('strict migration rejects legacy queue/reservation but permits in-flight settlement',async t=>{
 const legacy=setup(t);
 legacy.reserve(intent);
 legacy.reserve({...intent,requestId:'queued'});
 const strict=openModelLedger(legacy.testPath,{requireConfigurationVersion:true});t.after(()=>strict.close());
 assert.equal(strict.admitQueued('queued',1).record.request.state,'rejected-before-dispatch');
 assert.equal(strict.transition('request',1,'dispatch').request.state,'rejected-before-dispatch');
 assert.equal(strict.scope('account','account').reserved,0n);
 // A request already dispatched by the previous deployment still owes its usage.
 legacy.reserve({...intent,requestId:'inflight'});legacy.transition('inflight',1,'dispatch');
 const receipt=strict.transition('inflight',2,'receipt',{inputTokens:1n,outputTokens:1n});
 assert.equal(strict.transition('inflight',receipt.version,'finish').request.state,'settled');
 assert.equal(strict.scope('account','account').spent,3n);
 assert.equal(strict.scope('api','api').active,0);
});
