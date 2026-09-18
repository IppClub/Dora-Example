import test from 'node:test';
import assert from 'node:assert/strict';
import {createServer,request} from 'node:http';
import {createAgentLaunchRoute} from '../apps/server/agent-launch-route.mjs';
import {createAgentLaunchStore} from '../apps/server/agent-launch-store.mjs';
test('launch API derives identity from authorization and rechecks before creating the URL',async()=>{
  const store=createAgentLaunchStore();let allowed=true,builds=0,revokeDuringBuild=false;
  const route=createAgentLaunchRoute({studioOrigin:'https://studio.example',hostOrigin:'https://host.example',store,engineVersion:'1.9.2',
    authorizeProject:async()=>allowed?{accountId:'owner',projectId:'p',title:'Authorized title'}:null,
    createSnapshot:async config=>{builds++;if(revokeDuringBuild)allowed=false;return {config,manifest:{},files:[]};}});
  const server=createServer(async(req,res)=>{if(!await route(req,res)){res.statusCode=404;res.end();}});
  await new Promise(done=>server.listen(0,'127.0.0.1',done));
  const url=`http://127.0.0.1:${server.address().port}/api/projects/p/agent-launch`;
  const options={method:'POST',headers:{Origin:'https://studio.example'}};
  try {
    assert.equal((await fetch(url,{method:'POST'})).status,403);
    assert.equal((await fetch(url,{...options,body:'{"accountId":"attacker"}'})).status,400);assert.equal(builds,0);
    const response=await fetch(url,options);assert.equal(response.status,201);
    const launch=await response.json();assert.equal(launch.projectId,'p');
    const id=new URL(launch.url).pathname.split('/')[2],snapshot=store.get(id);
    assert.equal(snapshot.config.accountId,'owner');assert.equal(snapshot.config.generation,launch.generation);
    assert.equal(snapshot.config.title,'Authorized title');assert.equal(new URL(launch.url).origin,'https://host.example');
    store.revoke(id);revokeDuringBuild=true;
    assert.equal((await fetch(url,options)).status,403);assert.equal(store.stats().entries,0);
    assert.equal((await fetch(url,options)).status,403);assert.equal(builds,2);
  }finally{await new Promise(done=>server.close(done));}
});
test('disconnect during snapshot preparation never admits an unreachable launch',async()=>{
  const store=createAgentLaunchStore();let release,entered,closed,finished,checks=0;
  const building=new Promise(resolve=>{entered=resolve;});
  const gate=new Promise(resolve=>{release=resolve;});
  const disconnected=new Promise(resolve=>{closed=resolve;});
  const handled=new Promise(resolve=>{finished=resolve;});
  const route=createAgentLaunchRoute({studioOrigin:'https://studio.example',hostOrigin:'https://host.example',store,engineVersion:'1.9.2',
    authorizeProject:async()=>{checks++;return {accountId:'owner',projectId:'p',title:'Title'};},
    createSnapshot:async config=>{entered();await gate;return {config,manifest:{},files:[]};}});
  const server=createServer(async(req,res)=>{res.on('close',closed);await route(req,res);finished();});
  await new Promise(done=>server.listen(0,'127.0.0.1',done));
  const client=request({host:'127.0.0.1',port:server.address().port,path:'/api/projects/p/agent-launch',method:'POST',headers:{Origin:'https://studio.example'}});
  client.on('error',()=>{});client.end();
  try {
    await building;client.destroy();await disconnected;release();await handled;
    assert.equal(checks,1);assert.deepEqual(store.stats(),{entries:0,bytes:0});
  }finally{release();client.destroy();await new Promise(done=>server.close(done));}
});
