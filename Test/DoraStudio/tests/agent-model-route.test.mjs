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
import {openModelStores} from '../apps/server/model-stores.mjs';
import {createAgentServiceHandler} from '../apps/server/agent-service-handler.mjs';
import {SESSION_COOKIE_NAME} from '../apps/server/session-authenticate.mjs';
import {loadTrustedProviderDefinitions} from '../apps/server/trusted-provider-definitions.mjs';

test('trusted deployment provider allowlist rejects browser URLs and unsafe endpoints',()=>{
  const allowed=new Set(['fixture']);
  assert.deepEqual([...loadTrustedProviderDefinitions(undefined,allowed)],[]);
  assert.deepEqual(loadTrustedProviderDefinitions(JSON.stringify({fixture:{endpoint:'https://provider.example/v1/chat/completions',includeStreamUsage:true}}),allowed).get('fixture'),{endpoint:'https://provider.example/v1/chat/completions',includeStreamUsage:true});
  for(const value of [
    {other:{endpoint:'https://provider.example/v1/chat/completions'}},
    {fixture:{endpoint:'http://provider.example/v1/chat/completions'}},
    {fixture:{endpoint:'https://user:password@provider.example/v1/chat/completions'}},
    {fixture:{endpoint:'https://provider.example/v1/chat/completions?key=x'}},
    {fixture:{endpoint:'https://provider.example/v1/chat/completions',headers:{'x-key':'x'}}},
  ])assert.throws(()=>loadTrustedProviderDefinitions(JSON.stringify(value),allowed),/Invalid provider definitions|Invalid trusted provider endpoint/);
});

test('live Agent launch dispatches only owned shared grants; settled usage, SSE terminator and retries use one ledger request',async()=>{
  const dir=mkdtempSync(join(tmpdir(),'studio-agent-model-')),path=join(dir,'studio.sqlite');
  const sessions=openSessionStore(path),accounts=openAccountStore(path),projects=openProjectStore(path);
  const stores=openModelStores({path,providerIds:new Set(['deepseek']),activeKeyId:'fixture',keys:new Map([['fixture',new Uint8Array(32).fill(7)]])});
  const api=createServer(async(req,res)=>{if(!await handler.api(req,res)){res.statusCode=404;res.end();}});
  const host=createServer(async(req,res)=>{if(!await handler.host(req,res)){res.statusCode=404;res.end();}});
  let handler,sends=0,streamMode='good';
  try{
    accounts.put('owner',{enabled:true},{expectedVersion:0,actorId:'bootstrap'});
    accounts.put('other',{enabled:true},{expectedVersion:0,actorId:'bootstrap'});
    projects.save('owner',{requestId:'seed',baseRevision:0,name:'Game',snapshot:{version:1,projectId:'game',revision:0,entry:'main.ts',files:[{path:'main.ts',kind:'text',text:'export {}'}]}});
    const owner=sessions.issue('owner',{ttlMs:60000}).token,other=sessions.issue('other',{ttlMs:60000}).token;
    stores.catalog.put({id:'api',kind:'shared',ownerId:'platform',label:'Fixture',model:'fixture-model',providerId:'deepseek',enabled:true,pricing:{inputNanoCnyPerMillion:'1000000',outputNanoCnyPerMillion:'2000000'}},{expectedVersion:0,actorId:'bootstrap'});
    stores.vault.put({kind:'shared',ownerId:'platform',configurationId:'api'},new TextEncoder().encode('test-only-provider-key'),{expectedVersion:0,actorId:'bootstrap'});
    stores.ledger.configure('api','api',{enabled:true,limit:3},{actorId:'bootstrap'});
    stores.ledger.configure('account','owner',{enabled:true,limit:3,amountLimit:1000000000n},{actorId:'bootstrap'});
    stores.ledger.configure('grant','grant',{enabled:true,limit:3,amountLimit:1000000000n,accountId:'owner',apiId:'api'},{actorId:'bootstrap'});
    api.listen(0,'127.0.0.1');host.listen(0,'127.0.0.1');await Promise.all([once(api,'listening'),once(host,'listening')]);
    const studioOrigin=`http://127.0.0.1:${api.address().port}`,realHost=`http://127.0.0.1:${host.address().port}`,hostOrigin=`https://127.0.0.1:${host.address().port}`;
    handler=createAgentServiceHandler({studioOrigin,hostOrigin,sessions,accounts,projects,engineVersion:'test',createSnapshot:async config=>({config,manifest:{files:[]},files:[]}),modelGateway:{...stores,providers:new Map([['deepseek',{endpoint:'https://provider.example/v1/chat/completions',includeStreamUsage:true}]]),fetchImpl:async(_url,options)=>{
      sends++;
      assert.equal(options.headers.Authorization,'Bearer test-only-provider-key');
      const body=JSON.parse(options.body);
      assert.ok(body.model==='fixture-model'||body.model==='deepseek-flash');
      if(body.stream){
        assert.equal(body.stream_options.include_usage,true);
        const text=streamMode==='good'?'data: {"choices":[{"delta":{"content":"game"}}]}\n\ndata: {"choices":[],"usage":{"prompt_tokens":2,"completion_tokens":1}}\n\ndata: [DONE]\n\n':'data: {"choices":[{"delta":{"content":"partial"}}]}\n\n';
        return new Response(text,{status:200,headers:{'content-type':'text/event-stream'}});
      }
      return new Response(JSON.stringify({choices:[{message:{role:'assistant',content:'game'}}],usage:{prompt_tokens:2,completion_tokens:1}}),{status:200,headers:{'content-type':'application/json'}});
    }}});
    const cookie=token=>({cookie:`${SESSION_COOKIE_NAME}=${token}`});
    const issued=await fetch(studioOrigin+'/api/projects/game/agent-launch',{method:'POST',headers:{...cookie(owner),origin:studioOrigin}});assert.equal(issued.status,201);
    const launch=await issued.json(),launchId=/\/agent-host\/([^/]+)\/index\.html$/.exec(launch.url)?.[1];assert.ok(launchId);
    const url=`${realHost}/agent-host/${launchId}/model/grant`;
    const visionURL=`${realHost}/agent-host/${launchId}/vision/grant`;
    const configURL=`${realHost}/agent-host/${launchId}/model-config/grant`;
    assert.equal((await fetch(configURL,{headers:cookie(other)})).status,403);
    const hostConfig=await (await fetch(configURL,{headers:cookie(owner)})).json();
    assert.equal(hostConfig.llmConfig.model,'fixture-model');assert.equal(hostConfig.llmConfig.apiKey,'studio-agent');
    assert.equal(hostConfig.llmConfig.contextWindow,1000000);assert.equal(hostConfig.llmConfig.maxTokens,64000);
    assert.deepEqual(hostConfig.llmConfig.customOptions,{auxiliaryOptions:{max_tokens:8192,reasoning_effort:null,thinking:{type:'disabled'}}});
    assert.equal(hostConfig.llmConfig.url,`${hostOrigin}/agent-host/${launchId}/model/grant`);
    assert.deepEqual(hostConfig.llmConfig.studioVision,{provider:'deepseek',model:'deepseek-flash',url:`${hostOrigin}/agent-host/${launchId}/vision/grant`});
    assert.equal(JSON.stringify(hostConfig).includes('test-only-provider-key'),false);
    const invoke=(token,id,body,extra={})=>fetch(url,{method:'POST',headers:{...cookie(token),origin:hostOrigin,'content-type':'application/json','x-studio-model-request-id':id,...extra},body:JSON.stringify(body)});
    const invokeVision=(token,id,body,extra={})=>fetch(visionURL,{method:'POST',headers:{...cookie(token),origin:hostOrigin,'content-type':'application/json','x-studio-model-request-id':id,...extra},body:JSON.stringify(body)});
    const plain={model:'fixture-model',messages:[{role:'user',content:'create a game'}],max_tokens:2,stream:false};
    const vision={model:'deepseek-flash',messages:[{role:'system',content:'inspect'},{role:'user',content:[{type:'text',text:'what is visible?'},{type:'image_url',image_url:{url:'data:image/png;base64,iVBORw0KGgo='}}]}],max_tokens:2,stream:false};
    assert.equal((await invoke(other,'foreign',plain)).status,403);
    assert.equal((await invoke(owner,'cross',plain,{origin:studioOrigin})).status,403);
    assert.equal((await fetch(url,{method:'POST',headers:{...cookie(owner),origin:hostOrigin,'content-type':'application/json'},body:JSON.stringify(plain)})).status,400);
    assert.equal((await invoke(owner,'wrong-model',{...plain,model:'other'})).status,403);
    assert.equal((await invokeVision(owner,'wrong-vision-model',{...vision,model:'fixture-model'})).status,403);
    assert.equal((await invokeVision(owner,'text-only',{...vision,messages:[{role:'system',content:'inspect'},{role:'user',content:[{type:'text',text:'no image'}]}]})).status,400);
    assert.equal(sends,0);
    const first=await invoke(owner,'first',plain);assert.equal(first.status,200);assert.equal((await first.json()).choices[0].message.content,'game');
    assert.equal(stores.ledger.scope('account','owner').spent,4n);
    assert.equal(stores.ledger.scope('grant','grant').spent,4n);
    const inspected=await invokeVision(owner,'vision',vision);assert.equal(inspected.status,200);assert.equal((await inspected.json()).choices[0].message.content,'game');
    assert.equal(stores.ledger.scope('account','owner').spent,8n);assert.equal(sends,2);
    const replay=await invoke(owner,'first',plain);assert.equal(replay.status,409);assert.equal((await replay.json()).error,'request-already-recorded');assert.equal(sends,2);
    assert.equal((await invoke(owner,'first',{...plain,messages:[{role:'user',content:'different'}]})).status,409);assert.equal(sends,2);
    const streamed=await invoke(owner,'stream',{...plain,stream:true});assert.equal(streamed.status,200);
    const text=await streamed.text();assert.ok(text.includes('data: [DONE]\n\n'));assert.ok(text.includes('game'));assert.equal(stores.ledger.scope('account','owner').spent,12n);
    assert.equal(sends,3);
    streamMode='broken';
    const partial=await invoke(owner,'broken',{...plain,stream:true});assert.equal(partial.status,200);
    const incomplete=await partial.text();assert.ok(incomplete.includes('partial'));assert.ok(!incomplete.includes('[DONE]'));
    assert.equal(stores.ledger.request(`${launchId}_broken`).request.state,'in-flight');
    assert.equal((await invoke(owner,'broken',{...plain,stream:true})).status,409);assert.equal(sends,4);
    stores.ledger.configure('account','owner',{enabled:true,limit:3,amountLimit:12n},{actorId:'bootstrap'});
    const noBudget=await invoke(owner,'no-budget',plain);assert.equal(noBudget.status,200);
    assert.deepEqual(await noBudget.json(),{error:{message:'当前账号的模型额度不足，请补充额度后重试。',type:'studio_gateway_error',code:'model-amount-insufficient'}});assert.equal(sends,4);
    const noBudgetStream=await invoke(owner,'no-budget-stream',{...plain,stream:true});assert.equal(noBudgetStream.status,200);
    const noBudgetText=await noBudgetStream.text();assert.ok(noBudgetText.includes('model-amount-insufficient'));assert.ok(noBudgetText.includes('data: [DONE]'));assert.equal(sends,4);
    sessions.revoke(owner);
    assert.equal((await invoke(owner,'revoked',plain)).status,403);assert.equal(sends,4);
  }finally{
    for(const server of [api,host]){server.closeAllConnections();await new Promise(resolve=>server.close(resolve));}
    stores.close();projects.close();accounts.close();sessions.close();rmSync(dir,{recursive:true,force:true});
  }
});
