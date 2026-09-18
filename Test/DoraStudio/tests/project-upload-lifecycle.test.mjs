import test from 'node:test';
import assert from 'node:assert/strict';
import {createServer,request} from 'node:http';
import {once} from 'node:events';
import {mkdtempSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {openProjectStore} from '../apps/server/project-store.mjs';
import {openAccountStore} from '../apps/server/account-store.mjs';
import {openSessionStore} from '../apps/server/session-store.mjs';
import {createSessionAuthenticator,SESSION_COOKIE_NAME} from '../apps/server/session-authenticate.mjs';
import {createProjectWriteRoute} from '../apps/server/project-write-route.mjs';

for(const mode of ['revoke','disable','timeout','oversize'])test(`project upload ${mode} leaves no snapshot or receipt`,{timeout:10000},async()=>{
 const dir=mkdtempSync(join(tmpdir(),'studio-upload-life-')),path=join(dir,'db');
 const projects=openProjectStore(path),accounts=openAccountStore(path),sessions=openSessionStore(path),peer=openSessionStore(path);let handler,upload;
 let checked;const authenticated=new Promise(resolve=>{checked=resolve;});
 const server=createServer(async(req,res)=>{if(!await handler(req,res)){res.statusCode=404;res.end();}});
 try{
  accounts.put('a',{enabled:true},{expectedVersion:0,actorId:'bootstrap'});const token=sessions.issue('a',{ttlMs:60000}).token;
  server.listen(0,'127.0.0.1');await once(server,'listening');const origin=`http://127.0.0.1:${server.address().port}`;
  const authenticate=createSessionAuthenticator({sessions,allowAccount:accounts.isAllowed});
  handler=createProjectWriteRoute({studioOrigin:origin,projects,maxBodyBytes:1024,bodyTimeoutMs:mode==='timeout'?30:5000,authenticate:async req=>{const actor=await authenticate(req);checked();return actor;}});
  const payload={expectedAccountId:'a',requestId:'one',baseRevision:0,name:'Game',snapshot:{version:1,projectId:'game',revision:0,entry:'init.lua',files:[{path:'init.lua',kind:'text',text:'print(1)'}]}};
  const body=JSON.stringify(payload);
  const result=new Promise(resolve=>{
   upload=request(origin+'/api/projects/game',{method:'PUT',headers:{origin,cookie:`${SESSION_COOKIE_NAME}=${token}`,'content-type':'application/json'}},res=>{res.resume();res.on('end',()=>resolve(res.statusCode));});
   upload.on('error',error=>resolve(error.code));upload.write(body.slice(0,1));
  });
  await authenticated;
  if(mode==='revoke')peer.revoke(token);
  if(mode==='disable')accounts.put('a',{enabled:false},{expectedVersion:1,actorId:'bootstrap'});
  if(mode!=='timeout')upload.end(mode==='oversize'?'x'.repeat(2048):body.slice(1));
  const status=await result;
  if(mode==='timeout')assert.equal(status,'ECONNRESET');else assert.equal(status,mode==='oversize'?413:401);
  assert.equal(projects.get('a','game'),null);assert.equal(projects.usage('a').versions,0);
  // Failure must not consume the idempotency key.
  assert.deepEqual(projects.save('a',payload),{cloudRevision:1,replayed:false});
 }finally{upload?.destroy();server.closeAllConnections();await new Promise(resolve=>server.close(resolve));peer.close();sessions.close();accounts.close();projects.close();rmSync(dir,{recursive:true,force:true});}
});
