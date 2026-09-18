import {test} from 'node:test';
import assert from 'node:assert/strict';
import {createServer} from 'node:http';
import {once} from 'node:events';
import {mkdtempSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {openSessionStore} from '../apps/server/session-store.mjs';
import {openAccountStore} from '../apps/server/account-store.mjs';
import {openModelStores} from '../apps/server/model-stores.mjs';
import {createAdminModelAllowancesHandler} from '../apps/server/admin-model-allowances-handler.mjs';
import {SESSION_COOKIE_NAME} from '../apps/server/session-authenticate.mjs';

test('administrator assigns account total and account×API money/concurrency scopes with real session and catalog binding',async()=>{
  const dir=mkdtempSync(join(tmpdir(),'studio-admin-allowance-')),path=join(dir,'studio.sqlite');
  const stores=openModelStores({path,providerIds:new Set(['fixture']),activeKeyId:'fixture',keys:new Map([['fixture',new Uint8Array(32).fill(7)]])}),sessions=openSessionStore(path),accounts=openAccountStore(path);
  accounts.put('admin',{enabled:true,administrator:true},{expectedVersion:0,actorId:'bootstrap'});
  accounts.put('creator',{enabled:true,administrator:false},{expectedVersion:0,actorId:'bootstrap'});
  accounts.put('other',{enabled:true,administrator:false},{expectedVersion:0,actorId:'bootstrap'});
  const admin=sessions.issue('admin',{ttlMs:60000}),creator=sessions.issue('creator',{ttlMs:60000}),options={actorId:'admin',sessionToken:admin.token};
  stores.catalog.put({id:'shared_api',kind:'shared',ownerId:'platform',label:'共享测试',model:'fixture-model',providerId:'fixture',enabled:false,pricing:{inputNanoCnyPerMillion:'1000000',outputNanoCnyPerMillion:'2000000'}},{...options,expectedVersion:0});
  stores.vault.put({kind:'shared',ownerId:'platform',configurationId:'shared_api'},new TextEncoder().encode('test-only-key'),{...options,expectedVersion:0});
  stores.ledger.configure('api','shared_api',{enabled:true,limit:3},options);
  stores.catalog.put({id:'shared_api',kind:'shared',ownerId:'platform',label:'共享测试',model:'fixture-model',providerId:'fixture',enabled:true},{...options,expectedVersion:1});
  let server,handler;
  try{
    server=createServer(async(req,res)=>{if(!await handler(req,res)){res.statusCode=404;res.end();}});
    server.listen(0,'127.0.0.1');await once(server,'listening');
    const origin=`http://127.0.0.1:${server.address().port}`;
    handler=createAdminModelAllowancesHandler({studioOrigin:origin,sessions,accounts,...stores});
    const request=(route,{method='GET',body,token=admin.token,requestOrigin=origin}={})=>fetch(origin+route,{method,headers:{...(token?{cookie:`${SESSION_COOKIE_NAME}=${token}`}:{}) ,...(method==='GET'?{}:{origin:requestOrigin,'content-type':'application/json'})},...(body===undefined?{}:{body:JSON.stringify(body)})});
    const account='/api/admin/model-accounts/creator',grant='/api/admin/model-grants/creator_shared_api';
    const total={enabled:true,limit:2,amountLimit:'10000000000'};
    assert.equal((await request(account,{method:'PUT',body:total,token:null})).status,401);
    assert.equal((await request(account,{method:'PUT',body:total,token:creator.token})).status,403);
    assert.equal((await request(account,{method:'PUT',body:total,requestOrigin:'https://foreign.example'})).status,403);
    const configured=await request(account,{method:'PUT',body:total});assert.equal(configured.status,200);
    assert.equal((await configured.json()).scope.amountLimit,'10000000000');
    const sub={accountId:'creator',apiId:'shared_api',enabled:true,limit:1,amountLimit:'5000000000'};
    const issued=await request(grant,{method:'PUT',body:sub});assert.equal(issued.status,200);
    assert.deepEqual((await issued.json()).scope,{enabled:true,limit:1,active:0,amountLimit:'5000000000',spent:'0',reserved:'0',accountId:'creator',apiId:'shared_api'});
    assert.equal(stores.ledger.allowance('creator','creator_shared_api').state,'available');
    const page=await request(account+'/grants?limit=20');assert.equal(page.status,200);
    assert.equal((await page.json()).items[0].grantId,'creator_shared_api');
    assert.equal((await request('/api/admin/model-accounts/other',{method:'PUT',body:total})).status,200);
    assert.equal((await request(grant,{method:'PUT',body:{...sub,accountId:'other'}})).status,409);
    assert.equal((await request('/api/admin/model-accounts/missing',{method:'PUT',body:total})).status,404);
    assert.equal((await request('/api/admin/model-grants/invalid',{method:'PUT',body:{...sub,apiId:'missing'}})).status,404);
    sessions.revoke(admin.token);
    assert.equal((await request(account,{method:'PUT',body:{...total,enabled:false}})).status,401);
    assert.equal(stores.ledger.scope('account','creator').enabled,true);
  }finally{
    server?.closeAllConnections();if(server)await new Promise(resolve=>server.close(resolve));
    accounts.close();sessions.close();stores.close();rmSync(dir,{recursive:true,force:true});
  }
});
