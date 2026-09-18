import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {execFile} from 'node:child_process';
import {promisify} from 'node:util';
import {DatabaseSync} from 'node:sqlite';
import {openModelLedger} from '../apps/server/model-ledger-sqlite.mjs';
const rates={inputNanoCnyPerMillion:1000000n,outputNanoCnyPerMillion:2000000n};
const request={requestId:'r1',accountId:'a',apiId:'p',grantId:'g',fingerprint:'normalized-payload-hash',reservation:10n,rates};
test('idempotency canonicalizes pricing and validates replay inputs before lookup',t=>{
 const {ledger}=setup(t);
 ledger.reserve({...request,rates:{...rates,unrelated:'must-not-persist'}});
 const reordered={outputNanoCnyPerMillion:2000000n,inputNanoCnyPerMillion:1000000n};
 assert.equal(ledger.reserve({...request,rates:reordered}).replayed,true);
 assert.deepEqual(ledger.request('r1').binding.rates,rates);
 for(const reservation of [10,'10',-1n,{$nano:'10'}])
  assert.throws(()=>ledger.reserve({...request,reservation}),/Invalid reservation/);
 assert.throws(()=>ledger.reserve({...request,rates:{...rates,inputNanoCnyPerMillion:{$nano:'1000000'}}}),/bigint/);
 assert.throws(()=>ledger.reserve({...request,rates:{...rates,inputNanoCnyPerMillion:2n}}),/binding mismatch/);
 assert.equal(ledger.scope('account','a').reserved,10n);
 assert.equal(ledger.request('r1').version,1);
});
function setup(t){
 const dir=mkdtempSync(join(tmpdir(),'studio-ledger-')),path=join(dir,'ledger.db');
 const handles=[];const open=()=>{const ledger=openModelLedger(path);handles.push(ledger);return ledger;};
 t.after(()=>{for(const ledger of handles)try{ledger.close();}catch{}rmSync(dir,{recursive:true,force:true});});
 const ledger=open();
 ledger.configure('api','p',{enabled:true,limit:1},{actorId:'test-admin'});
 ledger.configure('account','a',{enabled:true,limit:2,amountLimit:100n},{actorId:'test-admin'});
 ledger.configure('grant','g',{enabled:true,limit:1,amountLimit:50n,accountId:'a',apiId:'p'},{actorId:'test-admin'});
 return {ledger,open,path};
}
test('durable ledger survives reopening and stale transitions cannot double charge',t=>{
 const {ledger,open}=setup(t);
 assert.equal(ledger.reserve(request).record.version,1);ledger.close();
 const second=open();assert.equal(second.reserve(request).replayed,true);
 assert.equal(second.scope('api','p').active,1);
 assert.throws(()=>second.reserve({...request,fingerprint:'different'}),/binding mismatch/);
 const sent=second.transition('r1',1,'dispatch');assert.equal(sent.version,2);
 assert.throws(()=>second.transition('r1',1,'dispatch'),/version conflict/);
 second.transition('r1',2,'finish',null);second.close();
 const third=open();assert.equal(third.scope('api','p').active,0);assert.equal(third.scope('account','a').reserved,10n);
 third.transition('r1',3,'finish',{inputTokens:2n,outputTokens:1n});
 assert.throws(()=>third.transition('r1',3,'finish',{inputTokens:2n,outputTokens:1n}),/version conflict/);
 assert.equal(third.scope('account','a').spent,4n);assert.equal(third.scope('grant','g').spent,4n);
 assert.equal(third.scope('grant','g').reserved,0n);
});
test('independent connections share limits and failed dispatch rolls back unchanged',t=>{
 const {ledger,open}=setup(t),other=open();ledger.reserve(request);
 assert.equal(other.reserve({...request,requestId:'r2'}).decision.state,'queued');
 other.configure('grant','g',{enabled:false,limit:1,amountLimit:50n,accountId:'a',apiId:'p'},{actorId:'test-admin'});
 assert.throws(()=>ledger.transition('r1',1,'dispatch'),/unavailable/);
 assert.equal(ledger.request('r1').version,1);assert.equal(ledger.scope('grant','g').reserved,10n);
 other.transition('r1',1,'cancel');
 assert.equal(ledger.scope('api','p').active,0);assert.equal(ledger.scope('account','a').spent,0n);
 assert.equal(ledger.scope('account','a').reserved,0n);
 assert.throws(()=>ledger.reserve({...request,requestId:'bad',accountId:'other'}),/Unknown model scope/);
});
test('separate processes contend for one durable slot and only one dispatch wins',async t=>{
 const {ledger,path}=setup(t);
 const moduleUrl=new URL('../apps/server/model-ledger-sqlite.mjs',import.meta.url).href;
 const run=promisify(execFile);
 const worker=`import {openModelLedger} from ${JSON.stringify(moduleUrl)};
 const ledger=openModelLedger(process.argv[1]);
 try {
  const result=process.argv[3]==='dispatch'
   ? ledger.transition(process.argv[2],1,'dispatch')
   : ledger.reserve({requestId:process.argv[2],accountId:'a',apiId:'p',grantId:'g',fingerprint:'same',reservation:10n,rates:{inputNanoCnyPerMillion:1000000n,outputNanoCnyPerMillion:2000000n}});
  console.log(JSON.stringify({id:process.argv[2],state:result.record?.request.state??result.decision?.state??result.request.state}));
 } catch(error){console.log(JSON.stringify({error:error.message}));}finally{ledger.close();}`;
 const invoke=(key,action)=>run(process.execPath,['--input-type=module','-e',worker,path,key,action]).then(({stdout})=>JSON.parse(stdout));
 const results=await Promise.all(Array.from({length:8},(_,i)=>invoke(`concurrent-${i}`,'reserve')));
 assert.equal(results.filter(item=>item.state==='reserved').length,1);
 assert.equal(results.filter(item=>item.state==='queued').length,7);
 assert.equal(ledger.scope('api','p').active,1);assert.equal(ledger.scope('account','a').reserved,10n);
 const winner=results.find(item=>item.state==='reserved').id;
 const dispatches=await Promise.all([invoke(winner,'dispatch'),invoke(winner,'dispatch')]);
 assert.equal(dispatches.filter(item=>item.state==='in-flight').length,1);
 assert.equal(dispatches.filter(item=>item.error==='Request version conflict').length,1);
 assert.equal(ledger.request(winner).version,2);
});
test('request write failure rolls back all counter and amount mutations',t=>{
 const {ledger,path}=setup(t),fault=new DatabaseSync(path);t.after(()=>fault.close());
 fault.exec("CREATE TRIGGER fail_request_insert BEFORE INSERT ON model_requests BEGIN SELECT RAISE(ABORT,'injected storage failure'); END;");
 assert.throws(()=>ledger.reserve(request),/injected storage failure/);
 assert.equal(ledger.request('r1'),undefined);
 for(const kind of ['api','account','grant'])assert.equal(ledger.scope(kind,{api:'p',account:'a',grant:'g'}[kind]).active,0);
 assert.equal(ledger.scope('account','a').reserved,0n);assert.equal(ledger.scope('grant','g').reserved,0n);
 fault.exec('DROP TRIGGER fail_request_insert');ledger.reserve(request);ledger.transition('r1',1,'dispatch');
 fault.exec("CREATE TRIGGER fail_request_update BEFORE UPDATE ON model_requests BEGIN SELECT RAISE(ABORT,'injected storage failure'); END;");
 assert.throws(()=>ledger.transition('r1',2,'finish',{inputTokens:2n,outputTokens:1n}),/injected storage failure/);
 assert.equal(ledger.request('r1').version,2);assert.equal(ledger.request('r1').request.state,'in-flight');
 assert.equal(ledger.scope('api','p').active,1);assert.equal(ledger.scope('account','a').reserved,10n);
 assert.equal(ledger.scope('account','a').spent,0n);assert.equal(ledger.scope('grant','g').spent,0n);
 fault.exec('DROP TRIGGER fail_request_update');ledger.transition('r1',2,'finish',{inputTokens:2n,outputTokens:1n});
 assert.equal(ledger.scope('account','a').spent,4n);
});
test('audit is durable, paginated, replay-safe and mandatory for successful mutations',t=>{
 const {ledger,path,open}=setup(t),fault=new DatabaseSync(path);t.after(()=>fault.close());
 assert.throws(()=>ledger.configure('api','p',{enabled:false,limit:0}),/identity/);
 const initial=ledger.audit();assert.equal(initial.length,3);
 assert.equal(initial[0].actorId,'test-admin');assert.equal(initial[0].before,null);
 ledger.reserve(request);ledger.reserve(request);
 assert.equal(ledger.audit().length,4);
 const tail=ledger.audit({after:initial.at(-1).sequence,limit:1});
 assert.equal(tail[0].action,'reserve');assert.equal(tail[0].request.reserved,10n);
 assert.equal(tail[0].fingerprint,undefined);assert.equal(tail[0].binding,undefined);
 ledger.transition('r1',1,'dispatch');
 fault.exec("CREATE TRIGGER fail_audit BEFORE INSERT ON model_audit BEGIN SELECT RAISE(ABORT,'audit unavailable'); END;");
 assert.throws(()=>ledger.transition('r1',2,'finish',{inputTokens:2n,outputTokens:1n}),/audit unavailable/);
 assert.equal(ledger.request('r1').version,2);assert.equal(ledger.scope('account','a').spent,0n);
 assert.equal(ledger.scope('api','p').active,1);assert.equal(ledger.audit().length,5);
 assert.throws(()=>ledger.configure('api','p',{enabled:false,limit:0},{actorId:'admin-2'}),/audit unavailable/);
 assert.equal(ledger.scope('api','p').enabled,true);
 fault.exec('DROP TRIGGER fail_audit');
 ledger.transition('r1',2,'finish',{inputTokens:2n,outputTokens:1n});ledger.close();
 const reopened=open(),events=reopened.audit();
 assert.deepEqual(events.map(event=>event.action),['configure','configure','configure','reserve','dispatch','finish']);
 assert.equal(events.at(-1).request.settlement.charged,4n);
 assert.throws(()=>reopened.audit({limit:1001}),/Invalid audit/);
 assert.throws(()=>reopened.audit({after:-1}),/Invalid audit/);
});
test('completion receipt is immutable and cannot be replaced by a different settlement',t=>{
 const {ledger,open}=setup(t);ledger.reserve(request);ledger.transition('r1',1,'dispatch');
 const usage={inputTokens:2n,outputTokens:1n,cachedInputTokens:1n,reasoningOutputTokens:1n,unrelated:'not stored'};
 ledger.transition('r1',2,'receipt',usage);usage.inputTokens=99n;
 assert.deepEqual(ledger.request('r1').receipt,{usage:{inputTokens:2n,outputTokens:1n,cachedInputTokens:1n,reasoningOutputTokens:1n}});
 assert.throws(()=>ledger.transition('r1',3,'receipt',null),/cannot accept/);
 assert.throws(()=>ledger.transition('r1',3,'finish',{inputTokens:0n,outputTokens:0n}),/mismatch/);
 assert.equal(ledger.request('r1').version,3);
 ledger.close();const reopened=open();
 assert.equal(reopened.request('r1').receipt.usage.cachedInputTokens,1n);
 assert.equal(reopened.request('r1').receipt.usage.reasoningOutputTokens,1n);
 const done=reopened.transition('r1',3,'finish');
 assert.equal(done.request.settlement.charged,4n);assert.equal(reopened.scope('api','p').active,0);
});
test('persisted missing usage receipt releases slots but still permits later usage reconciliation',t=>{
 const {ledger}=setup(t);ledger.reserve(request);ledger.transition('r1',1,'dispatch');
 ledger.transition('r1',2,'receipt',null);
 const pending=ledger.transition('r1',3,'finish');
 assert.equal(pending.request.state,'pending-usage');assert.equal(ledger.scope('api','p').active,0);
 assert.equal(ledger.scope('account','a').reserved,10n);
 ledger.transition('r1',4,'finish',{inputTokens:2n,outputTokens:1n});
 assert.equal(ledger.scope('account','a').spent,4n);assert.equal(ledger.scope('account','a').reserved,0n);
});
