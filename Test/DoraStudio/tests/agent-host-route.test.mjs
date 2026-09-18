import test from 'node:test';
import assert from 'node:assert/strict';
import {createServer} from 'node:http';
import {request} from 'node:http';
import {createAgentHostRoute} from '../apps/server/agent-host-route.mjs';
import {createAgentLaunchStore} from '../apps/server/agent-launch-store.mjs';
test('private launch routes authorize every resource and bind account, project and generation',async()=>{
  const config={accountId:'owner',projectId:'p',generation:'g'};
  let grants=0,loads=0;
  const route=createAgentHostRoute({authorize:async req=>{
    grants++;const accountId=req.headers['x-test-account'];
    return accountId?{accountId,projectId:'p',generation:req.headers['x-test-generation']??'g'}:null;
  },getLaunch:async()=>{loads++;return {config,manifest:{version:1},files:[{path:'Agent/Session.lua',bytes:Buffer.from('trusted Lua')}]};}});
  const server=createServer(async(req,res)=>{if(!await route(req,res)){res.statusCode=404;res.end();}});
  await new Promise(done=>server.listen(0,'127.0.0.1',done));
  const base=`http://127.0.0.1:${server.address().port}/agent-host/launch/`;
  try {
    for(const resource of ['host-config.json','host-manifest.json','host-files/Agent/Session.lua']){
      assert.equal((await fetch(base+resource)).status,403);assert.equal(loads,0);
    }
    for(const headers of [{'x-test-account':'other'},{'x-test-account':'owner','x-test-generation':'old'}])assert.equal((await fetch(base+'host-config.json',{headers})).status,403);
    const headers={'x-test-account':'owner'};
    const response=await fetch(base+'host-files/Agent/Session.lua',{headers});assert.equal(await response.text(),'trusted Lua');
    assert.equal(response.headers.get('cache-control'),'private, no-store');
    assert.equal((await fetch(base+'host-config.json',{headers,method:'HEAD'})).status,200);
    assert.equal((await fetch(base+'host-files/missing.lua',{headers})).status,404);
    const before=grants;assert.equal((await fetch(base+'host-config.json',{headers,method:'POST'})).status,405);assert.equal(grants,before);
    assert.equal(grants,8);
  }finally{await new Promise(done=>server.close(done));}
});
test('private resources become unavailable when the stored launch expires or is revoked',async()=>{
  let clock=0;const store=createAgentLaunchStore({now:()=>clock});
  const config={accountId:'a',projectId:'p',generation:'g'};
  const snapshot={config,manifest:{version:1},files:[{path:'init.lua',bytes:Buffer.from('trusted')}]};
  const route=createAgentHostRoute({authorize:async()=>config,getLaunch:async id=>store.get(id)});
  const server=createServer(async(req,res)=>{if(!await route(req,res)){res.statusCode=404;res.end();}});
  await new Promise(done=>server.listen(0,'127.0.0.1',done));
  const resource=id=>`http://127.0.0.1:${server.address().port}/agent-host/${id}/host-files/init.lua`;
  try {
    const launch=store.put(snapshot,5);assert.equal((await fetch(resource(launch.id))).status,200);
    clock=5;assert.equal((await fetch(resource(launch.id))).status,404);
    const second=store.put(snapshot,5);store.revoke(second.id);
    assert.equal((await fetch(resource(second.id))).status,404);
    assert.deepEqual(store.stats(),{entries:0,bytes:0});
  }finally{await new Promise(done=>server.close(done));}
});
test('private launch errors do not disclose provider details or access malformed paths',async()=>{
  let stage='authorization',authorizations=0,loads=0;
  const route=createAgentHostRoute({authorize:async()=>{
    authorizations++;if(stage==='authorization')throw Error('private authorization detail');
    return {accountId:'a',projectId:'p',generation:'g'};
  },getLaunch:async()=>{loads++;throw Error('private storage location');}});
  const server=createServer(async(req,res)=>{if(!await route(req,res)){res.statusCode=404;res.end();}});
  await new Promise(done=>server.listen(0,'127.0.0.1',done));
  const port=server.address().port;
  const read=path=>new Promise((resolve,reject)=>{
    request({host:'127.0.0.1',port,path},res=>{
      let body='';res.on('data',chunk=>body+=chunk);res.on('end',()=>resolve({status:res.statusCode,headers:res.headers,body}));
    }).on('error',reject).end();
  });
  try {
    for(const path of ['/agent-host/id/host-files/../secret','/agent-host/id/host-files/%2e%2e/secret','/agent-host/id/host-files//secret'])assert.equal((await read(path)).status,404);
    assert.equal(authorizations,0);assert.equal(loads,0);
    for(const mode of ['authorization','storage']){
      stage=mode;const result=await read('/agent-host/id/host-config.json');
      assert.equal(result.status,500);assert.equal(result.body,'');
      assert.equal(result.headers['cache-control'],'private, no-store');
      assert.equal(result.headers['x-content-type-options'],'nosniff');
    }
    assert.equal(loads,1);
  }finally{await new Promise(done=>server.close(done));}
});
