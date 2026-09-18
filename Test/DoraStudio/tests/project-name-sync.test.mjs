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
import {createProjectWriteRoute} from '../apps/server/project-write-route.mjs';

test('authenticated project upload persists a validated display name for cross-device lists',async()=>{
 const dir=mkdtempSync(join(tmpdir(),'studio-project-name-')),path=join(dir,'db');
 const projects=openProjectStore(path),accounts=openAccountStore(path),sessions=openSessionStore(path);let route;
 const server=createServer(async(req,res)=>{if(!await route(req,res)){res.statusCode=404;res.end();}});
 try{
  accounts.put('a',{enabled:true},{expectedVersion:0,actorId:'bootstrap'});const token=sessions.issue('a',{ttlMs:60000}).token;
  server.listen(0,'127.0.0.1');await once(server,'listening');const origin=`http://127.0.0.1:${server.address().port}`;
  route=createProjectWriteRoute({studioOrigin:origin,projects,authenticate:createSessionAuthenticator({sessions,allowAccount:accounts.isAllowed})});
  const payload={expectedAccountId:'a',requestId:'named',baseRevision:0,name:'雨夜小猫',snapshot:{version:1,projectId:'game',revision:0,entry:'main.ts',files:[{path:'main.ts',kind:'text',text:'export {}'}]}};
  const put=body=>fetch(origin+'/api/projects/game',{method:'PUT',headers:{origin,cookie:`${SESSION_COOKIE_NAME}=${token}`,'content-type':'application/json'},body:JSON.stringify(body)});
  assert.equal((await put({expectedAccountId:payload.expectedAccountId,requestId:'missing-name',baseRevision:payload.baseRevision,snapshot:payload.snapshot})).status,400);assert.equal(projects.get('a','game'),null);
  assert.equal((await put({...payload,requestId:'invalid',name:'\u0000'})).status,400);assert.equal(projects.get('a','game'),null);
  const response=await put(payload);assert.equal(response.status,200);assert.equal((await response.json()).cloudRevision,1);
  assert.equal(projects.get('a','game').name,'雨夜小猫');assert.equal(projects.list('a').items[0].name,'雨夜小猫');
  const remove=headers=>fetch(origin+'/api/projects/game',{method:'DELETE',headers:{cookie:`${SESSION_COOKIE_NAME}=${token}`,...headers}});
  assert.equal((await remove({})).status,403);assert.ok(projects.get('a','game'));
  assert.equal((await remove({origin,'x-studio-account':'other'})).status,409);assert.ok(projects.get('a','game'));
  assert.equal((await remove({origin,'x-studio-account':'a'})).status,204);assert.equal(projects.get('a','game'),null);
  assert.equal((await remove({origin,'x-studio-account':'a'})).status,204,'Project deletion is idempotent');
  const stale=await put({...payload,requestId:'stale-after-delete'});assert.equal(stale.status,409);assert.equal(stale.headers.get('x-studio-project-error'),'project-deleted');
 }finally{server.closeAllConnections();await new Promise(resolve=>server.close(resolve));sessions.close();accounts.close();projects.close();rmSync(dir,{recursive:true,force:true});}
});
