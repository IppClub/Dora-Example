import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {DatabaseSync} from 'node:sqlite';
import {openModelLedger} from '../apps/server/model-ledger-sqlite.mjs';
import {recoverModelReceipts as recover} from '../apps/server/model-recovery.mjs';
test('bounded recovery skips uncertain requests, survives failures and avoids double settlement',t=>{
 const dir=mkdtempSync(join(tmpdir(),'studio-recovery-')),path=join(dir,'ledger.db');
 let ledger=openModelLedger(path);const fault=new DatabaseSync(path);
 t.after(()=>{fault.close();ledger.close();rmSync(dir,{recursive:true,force:true});});
 for(const kind of ['api','account','grant'])ledger.configure(kind,kind,{enabled:true,limit:10,amountLimit:100n,accountId:'account',apiId:'api'},{actorId:'admin'});
 for(const requestId of ['a','b','c','uncertain']){
  ledger.reserve({requestId,accountId:'account',apiId:'api',grantId:'grant',fingerprint:requestId,reservation:10n,rates:{inputNanoCnyPerMillion:1000000n,outputNanoCnyPerMillion:1000000n}});
  ledger.transition(requestId,1,'dispatch');
  if(requestId!=='uncertain')ledger.transition(requestId,2,'receipt',requestId==='c'?null:{inputTokens:2n,outputTokens:1n});
 }
 ledger.close();ledger=openModelLedger(path);
 assert.deepEqual(ledger.recoveryReceipts({limit:2}).map(row=>row.requestId),['a','b']);
 fault.exec("CREATE TRIGGER fail_a BEFORE UPDATE ON model_requests WHEN NEW.id='a' BEGIN SELECT RAISE(ABORT,'transient error'); END;");
 const first=recover(ledger,{limit:2});
 assert.deepEqual(first.processed,[{requestId:'a',state:'retry-required'},{requestId:'b',state:'settled'}]);
 const second=recover(ledger,{after:first.cursor,limit:2});assert.equal(second.processed[0].state,'pending-usage');
 assert.equal(ledger.scope('account','account').spent,3n);
 fault.exec('DROP TRIGGER fail_a');
 assert.deepEqual(recover(ledger).processed,[{requestId:'a',state:'settled'}]);
 assert.deepEqual(recover(ledger).processed,[]);
 assert.equal(ledger.scope('account','account').spent,6n);
 assert.equal(ledger.scope('account','account').reserved,20n); // c + uncertain
 assert.equal(ledger.scope('api','api').active,1); // only uncertain
 assert.equal(ledger.request('uncertain').request.state,'in-flight');
 const controller=new AbortController();controller.abort();assert.equal(recover(ledger,{signal:controller.signal}).interrupted,true);
 assert.throws(()=>ledger.recoveryReceipts({limit:1001}),/Invalid recovery/);
});
