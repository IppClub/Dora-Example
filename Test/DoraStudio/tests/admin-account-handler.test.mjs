import test from 'node:test';
import assert from 'node:assert/strict';
import {createServer,request} from 'node:http';
import {once} from 'node:events';
import {mkdtempSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {openAccountStore} from '../apps/server/account-store.mjs';
import {openSessionStore} from '../apps/server/session-store.mjs';
import {SESSION_COOKIE_NAME} from '../apps/server/session-authenticate.mjs';
import {createAdminAccountHandler} from '../apps/server/admin-account-handler.mjs';
test('admin reads require current administrator permission and bound sessions on every request',async()=>{
 const dir=mkdtempSync(join(tmpdir(),'studio-admin-')),path=join(dir,'store.db'),accounts=openAccountStore(path),sessions=openSessionStore(path);let handler;
 const server=createServer(async(req,res)=>{if(!await handler(req,res)){res.statusCode=404;res.end();}});
 try{
  accounts.put('admin',{enabled:true,administrator:true},{expectedVersion:0,actorId:'bootstrap'});
  accounts.put('member',{enabled:true},{expectedVersion:0,actorId:'bootstrap'});
  const admin=sessions.issue('admin',{ttlMs:60000}).token,member=sessions.issue('member',{ttlMs:60000}).token;
  server.listen(0,'127.0.0.1');await once(server,'listening');const origin=`http://127.0.0.1:${server.address().port}`;
  handler=createAdminAccountHandler({studioOrigin:origin,sessions,accounts});
  const get=(suffix='',token=admin)=>fetch(origin+'/api/admin/'+suffix,{headers:token?{cookie:`${SESSION_COOKIE_NAME}=${token}`}:{}});
  const first=await get('accounts?limit=1');assert.equal(first.status,200);assert.equal(first.headers.get('cache-control'),'private, no-store');
  const body=await first.json();assert.equal(body.items[0].accountId,'admin');assert.equal(body.nextCursor,'admin');assert.equal(JSON.stringify(body).includes(admin),false);
  assert.equal((await (await get('accounts?after=admin&limit=1')).json()).items[0].accountId,'member');
  assert.equal((await (await get('account-audit?limit=1')).json()).items[0].actorId,'bootstrap');
  assert.equal((await (await get('accounts/member')).json()).accountId,'member');
  assert.equal((await get('accounts/missing')).status,404);
  assert.equal((await get('accounts/member?x=1')).status,400);
  for(const endpoint of ['accounts','account-audit','accounts/member']){
    assert.equal((await get(endpoint,'')).status,401);assert.equal((await get(endpoint,member)).status,403);
  }
  for(const suffix of ['accounts?actorId=admin','accounts?limit=101','accounts?limit=1&limit=2','account-audit?after=-1'])assert.equal((await get(suffix)).status,400);
  const put=(target,body,token=admin,headers={origin})=>fetch(origin+'/api/admin/accounts/'+target,{method:'PUT',headers:{cookie:`${SESSION_COOKIE_NAME}=${token}`,'content-type':'application/json',...headers},body:JSON.stringify(body)});
  const change={enabled:false,administrator:false,expectedVersion:1};
  assert.equal((await put('member',change,admin,{})).status,403);
  assert.equal((await put('member',change,member)).status,403);
  assert.equal((await put('member',{...change,actorId:'admin'})).status,400);
  assert.equal((await put('admin',change)).status,409);
  const changed=await put('member',change);assert.equal(changed.status,200);assert.equal((await changed.json()).version,2);
  assert.equal(accounts.isAllowed('member'),false);assert.equal((await put('member',change)).status,409);
  assert.equal((await put('missing',change)).status,404);
  accounts.put('admin',{enabled:true,administrator:false},{expectedVersion:1,actorId:'bootstrap'});assert.equal((await get('accounts')).status,403);
  accounts.put('admin',{enabled:false,administrator:true},{expectedVersion:2,actorId:'bootstrap'});assert.equal((await get('accounts')).status,401);
  accounts.put('admin',{enabled:true},{expectedVersion:3,actorId:'bootstrap'});sessions.revoke(admin);assert.equal((await get('account-audit')).status,401);
 }finally{server.closeAllConnections();await new Promise(resolve=>server.close(resolve));sessions.close();accounts.close();rmSync(dir,{recursive:true,force:true});}
});

for(const revoke of ['session','administrator'])test(`slow admin upload cannot write after ${revoke} revocation`,async()=>{
 const dir=mkdtempSync(join(tmpdir(),'studio-admin-race-')),path=join(dir,'store.db'),accounts=openAccountStore(path),sessions=openSessionStore(path);
 const peerAccounts=openAccountStore(path),peerSessions=openSessionStore(path);
 let handler,notifyChecked,timer,upload;
 const checked=new Promise(resolve=>{notifyChecked=resolve;});
 const server=createServer(async(req,res)=>{if(!await handler(req,res)){res.statusCode=404;res.end();}});
 try{
  accounts.put('admin',{enabled:true,administrator:true},{expectedVersion:0,actorId:'bootstrap'});
  accounts.put('target',{enabled:true},{expectedVersion:0,actorId:'bootstrap'});
  const {token}=sessions.issue('admin',{ttlMs:60000});
  server.listen(0,'127.0.0.1');await once(server,'listening');const origin=`http://127.0.0.1:${server.address().port}`;
  handler=createAdminAccountHandler({studioOrigin:origin,sessions,accounts:{...accounts,isAdministrator:id=>{const allowed=accounts.isAdministrator(id);notifyChecked(allowed);return allowed;}}});
  const body=JSON.stringify({enabled:false,administrator:false,expectedVersion:1});
  const response=new Promise((resolve,reject)=>{
    upload=request(origin+'/api/admin/accounts/target',{method:'PUT',headers:{origin,cookie:`${SESSION_COOKIE_NAME}=${token}`,'content-type':'application/json','content-length':Buffer.byteLength(body)}},res=>{res.resume();res.on('end',()=>resolve(res.statusCode));});
    upload.on('error',reject);upload.write(body.slice(0,1));
  });
  // Keep the body incomplete until the real initial permission check ran.
  assert.equal(await Promise.race([checked,new Promise((_,reject)=>{timer=setTimeout(()=>reject(new Error('Permission check timed out')),5000);})]),true);
  clearTimeout(timer);
  if(revoke==='session')peerSessions.revoke(token);
  else peerAccounts.put('admin',{enabled:true,administrator:false},{expectedVersion:1,actorId:'bootstrap'});
  const auditBefore=accounts.audit().items.length;
  upload.end(body.slice(1));assert.equal(await response,revoke==='session'?401:403);
  assert.deepEqual(accounts.get('target'),{accountId:'target',enabled:true,administrator:false,version:1});
  assert.equal(accounts.audit().items.length,auditBefore);
 }finally{clearTimeout(timer);upload?.destroy();server.closeAllConnections();await new Promise(resolve=>server.close(resolve));peerSessions.close();peerAccounts.close();sessions.close();accounts.close();rmSync(dir,{recursive:true,force:true});}
});
