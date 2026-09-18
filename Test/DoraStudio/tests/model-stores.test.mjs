import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {randomBytes} from 'node:crypto';
import {openModelStores} from '../apps/server/model-stores.mjs';

test('deployment assembly shares durable catalog/vault/ledger and enforces version binding',async t=>{
 const dir=mkdtempSync(join(tmpdir(),'studio-model-stores-'));
 t.after(()=>rmSync(dir,{recursive:true,force:true}));
 const options={path:join(dir,'models.db'),providerIds:new Set(['fixture']),activeKeyId:'key',keys:new Map([['key',randomBytes(32)]])};
 const stores=openModelStores(options);
 const binding={kind:'shared',ownerId:'platform',configurationId:'api'};
 try{
  stores.catalog.put({id:'api',kind:'shared',ownerId:'platform',label:'Fixture',model:'fixture',providerId:'fixture',enabled:true},{expectedVersion:0,actorId:'admin'});
  stores.vault.put(binding,Buffer.from('fixture-secret'),{expectedVersion:0,actorId:'admin'});
  for(const kind of ['api','account','grant'])stores.ledger.configure(kind,kind,{enabled:true,limit:1,amountLimit:100n,...(kind==='grant'?{accountId:'account',apiId:'api'}:{})},{actorId:'admin'});
  const intent={requestId:'request',accountId:'account',apiId:'api',grantId:'grant',fingerprint:'fixture',reservation:1n,rates:{inputNanoCnyPerMillion:1n,outputNanoCnyPerMillion:1n}};
  assert.equal(stores.ledger.reserve(intent).decision.state,'denied');
  assert.equal(stores.ledger.reserve({...intent,configurationVersion:1}).record.request.state,'reserved');
 }finally{stores.close();stores.close();}
 const reopened=openModelStores(options);
 try{
  assert.equal(reopened.catalog.get('api').version,1);
  assert.equal(reopened.ledger.request('request').binding.configurationVersion,1);
  await reopened.vault.withSecret(binding,bytes=>assert.equal(Buffer.from(bytes).toString(),'fixture-secret'));
 }finally{reopened.close();}
 assert.throws(()=>openModelStores({...options,path:':memory:'}),/absolute file path/);
 assert.throws(()=>openModelStores({...options,providerIds:new Set()}),/provider catalog/);
 const recovered=openModelStores(options);recovered.close();
});
