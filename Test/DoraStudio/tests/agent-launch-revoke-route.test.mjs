import test from 'node:test';
import assert from 'node:assert/strict';
import {createServer} from 'node:http';
import {createAgentLaunchStore} from '../apps/server/agent-launch-store.mjs';
import {createAgentLaunchRevokeRoute} from '../apps/server/agent-launch-revoke-route.mjs';
test('launch revocation verifies ownership, leaves foreign launches intact and is idempotent',async()=>{
  const store=createAgentLaunchStore();let account='owner';
  const launch=store.put({config:{accountId:'owner',projectId:'p',generation:'g'},manifest:{},files:[]});
  const route=createAgentLaunchRevokeRoute({studioOrigin:'https://studio.example',store,authorizeProject:async()=>account?{accountId:account,projectId:'p'}:null});
  const server=createServer(async(req,res)=>{if(!await route(req,res)){res.statusCode=404;res.end();}});
  await new Promise(done=>server.listen(0,'127.0.0.1',done));
  const url=`http://127.0.0.1:${server.address().port}/api/projects/p/agent-launch/${launch.id}`;
  const options={method:'DELETE',headers:{Origin:'https://studio.example'}};
  try {
    assert.equal((await fetch(url,{method:'DELETE'})).status,403);assert.ok(store.get(launch.id));
    account='other';assert.equal((await fetch(url,options)).status,403);assert.ok(store.get(launch.id));
    account='owner';assert.equal((await fetch(url,{...options,body:'unexpected'})).status,400);assert.ok(store.get(launch.id));
    assert.equal((await fetch(url,options)).status,204);assert.equal(store.get(launch.id),undefined);
    assert.equal((await fetch(url,options)).status,204);
    account=null;assert.equal((await fetch(url,options)).status,403);
  }finally{await new Promise(done=>server.close(done));}
});
