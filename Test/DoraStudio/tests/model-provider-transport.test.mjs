import {test} from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {sendCompatibleCompletion,compatibleCompletionUsage} from '../apps/server/model-provider-transport.mjs';
import {openModelStores} from '../apps/server/model-stores.mjs';
import {executeModelRequest} from '../apps/server/model-request-executor.mjs';

const endpoint='https://provider.example.invalid/v1/chat/completions',key=new TextEncoder().encode('test-only-provider-key');
const body={model:'test-model',messages:[{role:'user',content:'make a game'}],stream:false};
const response=(data,type='application/json')=>new Response(data,{status:200,headers:{'Content-Type':type}});

test('compatible provider response preserves billing totals and overlapping detail counters',async()=>{
  const calls=[];
  const result=await sendCompatibleCompletion({endpoint,key,body,fetchImpl:async(url,options)=>{
    calls.push({url,method:options.method,headers:options.headers,body:JSON.parse(options.body)});
    return response(JSON.stringify({choices:[{index:0,message:{role:'assistant',content:'game'}}],usage:{prompt_tokens:19,completion_tokens:7,total_tokens:26,prompt_tokens_details:{cached_tokens:5,audio_tokens:2},completion_tokens_details:{reasoning_tokens:3}}}));
  }});
  assert.equal(result.completed,true);
  assert.deepEqual(result.usage,{inputTokens:19n,outputTokens:7n,totalTokens:26n,cachedInputTokens:5n,inputAudioTokens:2n,reasoningOutputTokens:3n});
  assert.equal(result.response.choices[0].message.content,'game');
  assert.deepEqual(calls,[{url:endpoint,method:'POST',headers:{Authorization:'Bearer test-only-provider-key','Content-Type':'application/json',Accept:'application/json'},body}]);
});

test('stream forwards original SSE bytes and only completes after terminal marker',async()=>{
  const chunks=['data: {"choices":[{"delta":{"content":"hello"}}]}\n\n','data: {"choices":[],"usage":{"prompt_tokens":11,"completion_tokens":2}}\n\n','data: [DO','NE]\n\n'];
  const sent=[];
  const result=await sendCompatibleCompletion({endpoint,key,body:{...body,stream:true},onChunk:part=>sent.push(part),fetchImpl:async()=>response(new ReadableStream({start(controller){for(const chunk of chunks)controller.enqueue(new TextEncoder().encode(chunk));controller.close();}}),'text/event-stream')});
  assert.deepEqual(sent,chunks);
  assert.deepEqual(result,{completed:true,usage:{inputTokens:11n,outputTokens:2n},response:null});
});

test('trusted OpenAI stream policy requests terminal usage without changing Agent message/options',async()=>{
  let sent;
  const original={...body,stream:true,stream_options:{include_obfuscation:false}};
  await sendCompatibleCompletion({endpoint,key,body:original,includeStreamUsage:true,onChunk:()=>{},fetchImpl:async(_url,options)=>{
    sent=JSON.parse(options.body);
    return response('data: {"choices":[],"usage":{"prompt_tokens":1,"completion_tokens":1}}\n\ndata: [DONE]\n\n','text/event-stream');
  }});
  assert.deepEqual(sent,{...original,stream_options:{include_obfuscation:false,include_usage:true}});
  assert.deepEqual(original.stream_options,{include_obfuscation:false});
  await assert.rejects(sendCompatibleCompletion({endpoint,key,body,includeStreamUsage:true,fetchImpl:async()=>{throw new Error('must not send');}}),/Invalid stream usage policy/);
});

test('missing stream usage is unknown, not zero; missing terminator is unconfirmed',async()=>{
  const stream=text=>response(text,'text/event-stream');
  const noUsage=await sendCompatibleCompletion({endpoint,key,body:{...body,stream:true},onChunk:()=>{},fetchImpl:async()=>stream('data: {"choices":[{"delta":{"content":"x"}}]}\n\ndata: [DONE]\n\n')});
  assert.equal(noUsage.usage,null);
  await assert.rejects(sendCompatibleCompletion({endpoint,key,body:{...body,stream:true},onChunk:()=>{},fetchImpl:async()=>stream('data: {"choices":[{"delta":{"content":"x"}}]}\n\n')}),/Missing provider stream terminator/);
  await assert.rejects(sendCompatibleCompletion({endpoint,key,body:{...body,stream:true},onChunk:()=>{},fetchImpl:async()=>stream('data: {"error":{"message":"bad"}}\n\ndata: [DONE]\n\n')}),/Provider stream error/);
});

test('trusted endpoint and usage validation reject unsafe and ambiguous inputs',async()=>{
  for(const unsafe of ['http://provider.example.invalid/v1/chat/completions','https://user:password@provider.example.invalid/v1/chat/completions','https://provider.example.invalid/v1/chat/completions?key=x']){
    await assert.rejects(sendCompatibleCompletion({endpoint:unsafe,key,body,fetchImpl:async()=>{throw new Error('must not send');}}),/Invalid trusted provider endpoint/);
  }
  assert.throws(()=>compatibleCompletionUsage({prompt_tokens:Number.MAX_SAFE_INTEGER+1,completion_tokens:0}),/Invalid provider usage counter/);
  assert.throws(()=>compatibleCompletionUsage({prompt_tokens:1}),/Invalid provider usage counter/);
  await assert.rejects(sendCompatibleCompletion({endpoint,key,body,fetchImpl:async()=>response('{"error":"bad"}')}),/Invalid provider completion/);
  await assert.rejects(sendCompatibleCompletion({endpoint,key,body,fetchImpl:async()=>new Response('bad',{status:429})}),/Provider completion unavailable/);
});

test('trusted vault transport settles real returned usage through the existing shared ledger exactly once',async t=>{
  const dir=mkdtempSync(join(tmpdir(),'studio-provider-ledger-'));
  const stores=openModelStores({path:join(dir,'studio.sqlite'),providerIds:new Set(['fixture']),activeKeyId:'fixture',keys:new Map([['fixture',new Uint8Array(32).fill(7)]])});
  t.after(()=>{stores.close();rmSync(dir,{recursive:true,force:true});});
  stores.catalog.put({id:'api',kind:'shared',ownerId:'platform',label:'Fixture',model:'test-model',providerId:'fixture',enabled:true},{expectedVersion:0,actorId:'admin'});
  stores.vault.put({kind:'shared',ownerId:'platform',configurationId:'api'},key,{expectedVersion:0,actorId:'admin'});
  stores.ledger.configure('api','api',{enabled:true,limit:1},{actorId:'admin'});
  stores.ledger.configure('account','account',{enabled:true,limit:1,amountLimit:100n},{actorId:'admin'});
  stores.ledger.configure('grant','grant',{enabled:true,limit:1,amountLimit:100n,accountId:'account',apiId:'api'},{actorId:'admin'});
  const intent={requestId:'provider-request',accountId:'account',apiId:'api',grantId:'grant',fingerprint:'trusted-completion-payload',reservation:10n,configurationVersion:1,rates:{inputNanoCnyPerMillion:1000000n,outputNanoCnyPerMillion:2000000n}};
  let sends=0;
  const run=()=>stores.vault.withSecret({kind:'shared',ownerId:'platform',configurationId:'api'},secret=>executeModelRequest({ledger:stores.ledger,intent,send:({signal})=>sendCompatibleCompletion({endpoint,key:secret,body,signal,fetchImpl:async()=>{sends++;return response(JSON.stringify({choices:[{message:{role:'assistant',content:'created'}}],usage:{prompt_tokens:2,completion_tokens:1}}));}})}));
  const result=await run();
  assert.equal(result.state,'settled');assert.equal(result.response.choices[0].message.content,'created');
  assert.equal(stores.ledger.scope('account','account').spent,4n);
  assert.equal(stores.ledger.scope('grant','grant').spent,4n);
  assert.equal(stores.ledger.scope('account','account').reserved,0n);
  assert.equal((await run()).state,'existing');assert.equal(sends,1);
});
