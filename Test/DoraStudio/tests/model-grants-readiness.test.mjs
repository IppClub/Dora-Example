import test from 'node:test';
import assert from 'node:assert/strict';
import {createServer} from 'node:http';
import {once} from 'node:events';
import {createModelGrantsRoute} from '../apps/server/model-grants-route.mjs';

test('creator choices require a live shared endpoint, secret and account allowance',async()=>{
  let available=false,state='available',enabled=true;
  const providers=new Map();
  const route=createModelGrantsRoute({studioOrigin:'http://studio.test',authenticate:async req=>req.headers.authorization==='owner'?{accountId:'owner'}:null,
    ledger:{grantsForAccount:()=>[{grantId:'grant',apiId:'api'}],allowance:()=>({state})},
    catalog:{get:()=>({id:'api',kind:'shared',ownerId:'platform',label:'平台模型',model:'model',providerId:'supplier',enabled})},
    vault:{metadata:()=>({available})},gatewayProviders:providers});
  const server=createServer(async(req,res)=>{if(!await route(req,res)){res.statusCode=404;res.end();}});
  try{
    server.listen(0,'127.0.0.1');await once(server,'listening');
    const read=async(headers={authorization:'owner'})=>{
      const response=await fetch(`http://127.0.0.1:${server.address().port}/api/model-grants`,{headers});
      return {status:response.status,body:response.status===200?await response.json():null};
    };
    assert.equal((await read()).body.configurations[0].enabled,false);
    providers.set('supplier',{endpoint:'https://supplier.example/v1/chat/completions'});
    assert.equal((await read()).body.configurations[0].enabled,false);
    available=true;assert.equal((await read()).body.configurations[0].enabled,true);
    state='zero-capacity';assert.equal((await read()).body.configurations[0].enabled,false);
    state='insufficient-amount';assert.equal((await read()).body.configurations[0].enabled,false);
    state='concurrency';assert.equal((await read()).body.configurations[0].enabled,false);
    state='available';enabled=false;assert.equal((await read()).body.configurations[0].enabled,false);
    assert.equal((await read({authorization:'other'})).status,401);
    assert.equal((await read({authorization:'owner',origin:'http://other.test'})).status,403);
  }finally{server.closeAllConnections();await new Promise(resolve=>server.close(resolve));}
});
