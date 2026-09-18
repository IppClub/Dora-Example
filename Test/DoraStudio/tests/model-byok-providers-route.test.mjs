import test from 'node:test';
import assert from 'node:assert/strict';
import {createServer} from 'node:http';
import {once} from 'node:events';
import {createByokProvidersRoute} from '../apps/server/model-byok-providers-route.mjs';
test('provider discovery authenticates and projects only immutable public choices',async t=>{
 const providers=[{id:'approved',label:'Approved provider',key:'never-public',endpoint:'http://private.test',headers:{Authorization:'secret'}}];
 const options={studioOrigin:'http://studio.test',authenticate:async req=>req.headers.authorization?{accountId:'a'}:null,providers};
 assert.throws(()=>createByokProvidersRoute({...options,providers:[providers[0],providers[0]]}));
 const route=createByokProvidersRoute(options);providers[0].label='mutated';providers.push({id:'extra',label:'Extra'});
 const server=createServer(async(req,res)=>{if(!await route(req,res)){res.statusCode=404;res.end();}});server.listen(0,'127.0.0.1');await once(server,'listening');t.after(()=>new Promise(resolve=>{server.closeAllConnections();server.close(resolve);}));
 const get=(suffix='',headers={authorization:'fixture'})=>fetch(`http://127.0.0.1:${server.address().port}/api/byok/providers${suffix}`,{headers});
 const response=await get();assert.equal(response.status,200);assert.equal(response.headers.get('cache-control'),'private, no-store');assert.deepEqual(await response.json(),{version:1,providers:[{id:'approved',label:'Approved provider'}]});
 assert.equal((await get('',{})).status,401);assert.equal((await get('?owner=a')).status,400);assert.equal((await get('',{authorization:'fixture',origin:'https://foreign.test'})).status,403);
});
