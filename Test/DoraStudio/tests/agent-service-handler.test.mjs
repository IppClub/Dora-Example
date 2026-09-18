import test from 'node:test';
import assert from 'node:assert/strict';
import {createServer} from 'node:http';
import {once} from 'node:events';
import {mkdtempSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {openSessionStore} from '../apps/server/session-store.mjs';
import {openAccountStore} from '../apps/server/account-store.mjs';
import {openProjectStore} from '../apps/server/project-store.mjs';
import {createAgentServiceHandler} from '../apps/server/agent-service-handler.mjs';
import {createAgentLaunchStore} from '../apps/server/agent-launch-store.mjs';
import {loadAgentHostAssets} from '../apps/server/agent-host-assets.mjs';
import {SESSION_COOKIE_NAME} from '../apps/server/session-authenticate.mjs';

test('Agent launch and private files require a live invited account owning a cloud project',async()=>{
  const dir=mkdtempSync(join(tmpdir(),'studio-agent-service-')),path=join(dir,'studio.db');
  const sessions=openSessionStore(path),accounts=openAccountStore(path),projects=openProjectStore(path);
  accounts.put('owner',{enabled:true},{expectedVersion:0,actorId:'bootstrap'});
  accounts.put('other',{enabled:true},{expectedVersion:0,actorId:'bootstrap'});
  projects.save('owner',{requestId:'seed',baseRevision:0,name:'Game',snapshot:{version:1,projectId:'game',revision:0,entry:'main.ts',files:[{path:'main.ts',kind:'text',text:'export {}'}]}});
  const owner=sessions.issue('owner',{ttlMs:60000}).token,other=sessions.issue('other',{ttlMs:60000}).token;
  let handler,builds=0,clock=100;
  const store=createAgentLaunchStore({now:()=>clock});
  const api=createServer(async(req,res)=>{if(!await handler.api(req,res)){res.statusCode=404;res.end();}});
  const host=createServer(async(req,res)=>{if(!await handler.host(req,res)){res.statusCode=404;res.end();}});
  try{
    api.listen(0,'127.0.0.1');host.listen(0,'127.0.0.1');await Promise.all([once(api,'listening'),once(host,'listening')]);
    const studioOrigin=`http://127.0.0.1:${api.address().port}`,hostOrigin=`http://127.0.0.1:${host.address().port}`;
    handler=createAgentServiceHandler({studioOrigin,hostOrigin,sessions,accounts,projects,store,engineVersion:'test',assets:new Map([['index.html',Buffer.from('<html>trusted host</html>')],['compiler/worker.js',Buffer.from('trusted worker')]]),createSnapshot:async config=>{
      builds++;return {config,manifest:{files:[]},files:[]};
    }});
    const cookie=token=>({cookie:`${SESSION_COOKIE_NAME}=${token}`});
    const launch=token=>fetch(`${studioOrigin}/api/projects/game/agent-launch`,{method:'POST',headers:{...cookie(token),origin:studioOrigin}});
    assert.equal((await launch(other)).status,403);
    assert.equal((await launch('')).status,403);
    assert.equal(builds,0);
    const issued=await launch(owner);assert.equal(issued.status,201);
    const data=await issued.json();assert.equal(data.projectId,'game');assert.equal(builds,1);
    assert.equal((await fetch(data.url,{headers:cookie(other)})).status,403);
    assert.equal((await (await fetch(data.url,{headers:cookie(owner)})).text()),'<html>trusted host</html>');
    const workerUrl=data.url.replace(/index\.html$/,'compiler/worker.js');
    assert.equal((await fetch(workerUrl,{headers:cookie(other)})).status,403);
    assert.equal((await (await fetch(workerUrl,{headers:cookie(owner)})).text()),'trusted worker');
    assert.equal((await fetch(data.url.replace(/index\.html$/,'compiler/../worker.js'),{headers:cookie(owner)})).status,404);
    assert.equal((await fetch(data.url+'?uncached',{headers:cookie(owner)})).status,404);
    const configUrl=data.url.replace(/index\.html$/,'host-config.json');
    assert.equal((await fetch(configUrl,{headers:cookie(other)})).status,403);
    assert.equal((await fetch(configUrl,{headers:cookie(owner)})).status,200);
    assert.equal((await (await fetch(configUrl,{headers:cookie(owner)})).json()).accountId,'owner');
    const renewUrl=data.url.replace(/index\.html$/,'renew');
    const renew=(token,origin=hostOrigin,body)=>fetch(renewUrl,{method:'POST',headers:{...cookie(token),origin},...(body===undefined?{}:{body})});
    assert.equal((await fetch(renewUrl,{headers:{...cookie(owner),origin:hostOrigin}})).status,405);
    assert.equal((await renew(owner,studioOrigin)).status,403);
    assert.equal((await renew(other)).status,403);
    assert.equal((await renew(owner,hostOrigin,'hidden claim')).status,400);
    clock=data.expiresAt-1;
    const renewed=await renew(owner);assert.equal(renewed.status,200);
    const lease=await renewed.json();assert.equal(lease.version,1);assert.ok(lease.expiresAt>data.expiresAt);
    clock=data.expiresAt+1;
    assert.equal((await fetch(configUrl,{headers:cookie(owner)})).status,200);
    assert.equal((await launch(owner)).status,201);
    accounts.put('owner',{enabled:false},{expectedVersion:1,actorId:'bootstrap'});
    assert.equal((await renew(owner)).status,403);
    assert.equal((await fetch(data.url,{headers:cookie(owner)})).status,403);
    assert.equal((await fetch(workerUrl,{headers:cookie(owner)})).status,403);
    assert.equal((await fetch(configUrl,{headers:cookie(owner)})).status,403);
    assert.equal((await launch(owner)).status,403);
    accounts.put('owner',{enabled:true},{expectedVersion:2,actorId:'bootstrap'});
    sessions.revoke(owner);
    assert.equal((await renew(owner)).status,403);
    assert.equal((await fetch(configUrl,{headers:cookie(owner)})).status,403);
    assert.equal((await launch(owner)).status,403);
    assert.equal(builds,2);
  }finally{
    for(const server of [api,host]){server.closeAllConnections();await new Promise(resolve=>server.close(resolve));}
    projects.close();accounts.close();sessions.close();rmSync(dir,{recursive:true,force:true});
  }
});

test('host asset loader rejects game Player and serves only authorized dedicated resources',async()=>{
  const dir=mkdtempSync(join(tmpdir(),'studio-agent-assets-'));
  try{
    const {writeFileSync}=await import('node:fs');
    for(const name of ['dora-player-runtime.js','dora-player-runtime.wasm','dora-player-runtime.data',
      'audio-worklet.js','dora-audio-mixer.wasm'])writeFileSync(join(dir,name),Buffer.from('fixture'));
    writeFileSync(join(dir,'dora-web-features.json'),JSON.stringify({activeProfile:'dora-preset'}));
    assert.throws(()=>loadAgentHostAssets(dir),/not a dedicated/);
    writeFileSync(join(dir,'dora-web-features.json'),JSON.stringify({activeProfile:'dora-preset',studioAgentHost:true}));
    writeFileSync(join(dir,'dora-web-manifest.json'),JSON.stringify({format:'dora-web-game',profile:'dora-preset',engineVersion:'test'}));
    const {assets,engineVersion}=loadAgentHostAssets(dir);
    assert.equal(engineVersion,'test');
    assert.ok(assets.get('index.html').includes('Agent'));
    assert.equal(assets.get('dora-player-runtime.wasm').toString(),'fixture');
  }finally{rmSync(dir,{recursive:true,force:true});}
});
