import test from 'node:test';
import assert from 'node:assert/strict';
import {createServer} from 'node:http';
import {once} from 'node:events';
import {createSessionRoute} from '../apps/server/session-route.mjs';

test('session projection uses live trusted identity without exposing authentication data',async t=>{
 let identity={accountId:'account-a',token:'private-token',email:'private@example.test',roles:['admin']};let calls=0;
 const route=createSessionRoute({studioOrigin:'http://studio.test',authenticate:async()=>{calls++;return identity;}});
 const server=createServer(async(req,res)=>{if(!await route(req,res)){res.statusCode=404;res.end();}});
 server.listen(0,'127.0.0.1');await once(server,'listening');
 t.after(()=>new Promise(resolve=>{server.closeAllConnections();server.close(resolve);}));
 const request=(path='/api/session',options={})=>fetch(`http://127.0.0.1:${server.address().port}${path}`,options);
 const first=await request('/api/session',{headers:{'x-account-id':'forged'}});
 assert.equal(first.status,200);assert.equal(first.headers.get('cache-control'),'private, no-store');
 assert.equal(first.headers.get('set-cookie'),null);
 assert.deepEqual(await first.json(),{version:1,account:{accountId:'account-a'}});
 identity={accountId:'account-b'};
 assert.deepEqual(await (await request()).json(),{version:1,account:{accountId:'account-b'}});
 identity=null;assert.equal((await request()).status,401);
 const before=calls;
 assert.equal((await request('/api/session?accountId=forged')).status,400);
 assert.equal((await request('/api/session',{headers:{origin:'https://foreign.test'}})).status,403);
 assert.equal((await request('/api/session',{headers:{'sec-fetch-site':'cross-site'}})).status,403);
 assert.equal((await request('/api/session',{method:'POST'})).status,405);
 assert.equal((await request('/unrelated')).status,404);assert.equal(calls,before);
 identity={accountId:'\ud800'};assert.equal((await request()).status,500);
});

test('session route requires explicit authentication and hides its failures',async()=>{
 assert.throws(()=>createSessionRoute({studioOrigin:'http://studio.test'}),/Invalid session route/);
 const route=createSessionRoute({studioOrigin:'http://studio.test',authenticate:async()=>{throw new Error('secret');}});
 const response={setHeader(){},end(body){assert.equal(body,undefined);}};
 assert.equal(await route({url:'/api/session',method:'GET',headers:{}},response),true);
 assert.equal(response.statusCode,500);
});
