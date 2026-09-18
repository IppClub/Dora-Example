import test from 'node:test';
import assert from 'node:assert/strict';
import {createServer} from 'node:http';
import {once} from 'node:events';
import {mkdtempSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {openProjectStore} from '../apps/server/project-store.mjs';
import {openAccountStore} from '../apps/server/account-store.mjs';
import {openSessionStore} from '../apps/server/session-store.mjs';
import {createSessionAuthenticator,SESSION_COOKIE_NAME} from '../apps/server/session-authenticate.mjs';
import {createProjectReadRoute} from '../apps/server/project-read-route.mjs';
test('project HTTP reads bind source access to live session owner, with bounded history and binary transport',async()=>{
 const dir=mkdtempSync(join(tmpdir(),'studio-project-http-')),path=join(dir,'db');
 const projects=openProjectStore(path),accounts=openAccountStore(path),sessions=openSessionStore(path);let route;
 const server=createServer(async(req,res)=>{if(!await route(req,res)){res.statusCode=404;res.end();}});
 try{
  for(const id of ['a','b'])accounts.put(id,{enabled:true},{expectedVersion:0,actorId:'bootstrap'});
  const token=sessions.issue('a',{ttlMs:60000}).token,other=sessions.issue('b',{ttlMs:60000}).token;
  projects.save('a',{requestId:'one',baseRevision:0,name:'跨设备游戏',snapshot:{version:1,projectId:'game',revision:5,entry:'init.lua',files:[{path:'init.lua',kind:'text',text:'print(1)'},{path:'raw.bin',kind:'binary',bytes:new Uint8Array([0,255])}]}});
  server.listen(0,'127.0.0.1');await once(server,'listening');const origin=`http://127.0.0.1:${server.address().port}`;
  route=createProjectReadRoute({studioOrigin:origin,projects,authenticate:createSessionAuthenticator({sessions,allowAccount:accounts.isAllowed})});
  const get=(suffix='',credential=token)=>fetch(origin+'/api/projects'+suffix,{headers:credential?{cookie:`${SESSION_COOKIE_NAME}=${credential}`,'x-account-id':'a'}:{}});
  assert.equal((await get('','')).status,401);
  assert.equal((await fetch(origin+'/api/projects/game',{headers:{cookie:`${SESSION_COOKIE_NAME}=${token}`,'x-studio-account':'b'}})).status,409);
  const listed=(await (await get()).json()).items;assert.equal(Number.isSafeInteger(listed[0].updatedAt),true);assert.deepEqual(listed.map(({updatedAt,...item})=>item),[{projectId:'game',cloudRevision:1,name:'跨设备游戏'}]);
  assert.deepEqual((await (await get('',other)).json()).items,[]);
  for(const suffix of ['/game','/game/versions/1'])assert.equal((await get(suffix,other)).status,404);
  const read=await get('/game/versions/1');assert.equal(read.headers.get('cache-control'),'private, no-store');
  const readBody=await read.json();assert.equal(readBody.name,'跨设备游戏');assert.equal(readBody.snapshot.files.find(file=>file.kind==='binary').base64,'AP8=');
  const history=(await (await get('/game/history?limit=1')).json()).items;assert.equal(Number.isSafeInteger(history[0].updatedAt),true);assert.deepEqual(history.map(({updatedAt,...item})=>item),[{cloudRevision:1}]);
  for(const suffix of ['?owner=a','?limit=101','/game?owner=a','/game/history?after=-1','/game/versions/9007199254740992'])assert.equal((await get(suffix)).status,400);
  assert.equal((await fetch(origin+'/api/projects',{method:'PUT'})).status,405);
  accounts.put('a',{enabled:false},{expectedVersion:1,actorId:'bootstrap'});assert.equal((await get('/game')).status,401);
 }finally{server.closeAllConnections();await new Promise(resolve=>server.close(resolve));projects.close();accounts.close();sessions.close();rmSync(dir,{recursive:true,force:true});}
});
