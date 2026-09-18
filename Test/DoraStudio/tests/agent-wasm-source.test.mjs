import test from 'node:test';
import assert from 'node:assert/strict';
import {build} from 'esbuild';
const bundle=await build({entryPoints:['apps/web/src/agent-wasm-source.ts'],bundle:true,write:false,format:'esm',platform:'node'});
const {createAgentWasmSource:create}=await import('data:text/javascript;base64,'+Buffer.from(bundle.outputFiles[0].text).toString('base64'));
const detail={success:true,session:{id:1,projectRoot:'/game',title:'test',kind:'main',rootSessionId:1,memoryScope:'main',workMode:'code',status:'IDLE',createdAt:1,updatedAt:1},messages:[],steps:[],relatedSessions:[],hasActivePlan:false};
test('snapshot requests match only their own callback and emit a fixed native operation',async()=>{
  let request;
  const module={ccall:(name,result,types,args)=>{assert.equal(name,'dora_web_agent_request');request=JSON.parse(args[0]);}};
  const source=create(module,1);
  try {
    const pending=source.capture(new AbortController().signal);
    assert.equal(request.operation,'snapshot');
    module.doraStudioAgentEvent(JSON.stringify({kind:'snapshot',sessionId:1,sequence:2,requestId:'old',payload:JSON.stringify(detail)}));
    module.doraStudioAgentEvent(JSON.stringify({kind:'snapshot',sessionId:1,sequence:3,requestId:request.requestId,payload:JSON.stringify(detail)}));
    assert.equal((await pending).sequence,3);
  }finally{source.close();}
});
test('abort removes pending requests and late replies cannot settle a replacement',async()=>{
  const requests=[],module={ccall:(name,result,types,args)=>requests.push(JSON.parse(args[0]))};
  const source=create(module,1),abort=new AbortController();
  try {
    const old=source.capture(abort.signal);abort.abort();await assert.rejects(old);
    const fresh=source.capture(new AbortController().signal);
    for(const [index,request] of requests.entries())module.doraStudioAgentEvent(JSON.stringify({kind:'snapshot',sessionId:1,sequence:index+1,requestId:request.requestId,payload:JSON.stringify(detail)}));
    assert.equal((await fresh).sequence,2);
  }finally{source.close();}
});
test('invalid source callbacks retire ownership and notify subscribers',()=>{
  const module={ccall:()=>{}},source=create(module,1);let closed=0;
  source.subscribe(()=>{},()=>closed++);
  assert.throws(()=>module.doraStudioAgentEvent('{}'));
  assert.equal(closed,1);assert.equal(module.doraStudioAgentEvent,undefined);
  source.close();assert.equal(closed,1);
});
test('quiesce uses fixed native operation and rejects contradictory completion',async()=>{
  for(const invalid of [false,true]) {
    const module={ccall:(name,result,types,args)=>{
      const request=JSON.parse(args[0]);assert.equal(request.operation,'quiesce');
      module.doraStudioAgentEvent(JSON.stringify({kind:'snapshot',sessionId:1,sequence:0,requestId:request.requestId,payload:JSON.stringify({...detail,studioQuiescence:{success:true,quiescent:true,pending:invalid?[{sessionId:1,taskId:1,finalizing:false,stopRequested:true}]:[]}})}));
    }};
    const source=create(module,1);
    try {
      const result=source.quiesce(new AbortController().signal);
      if(invalid){await assert.rejects(result,/Invalid Agent quiescence/);assert.equal(module.doraStudioAgentEvent,undefined);}
      else assert.deepEqual(await result,{quiescent:true,pending:[]});
    }finally{source.close();}
  }
});
test('prompt request delivers trusted model binding to original Agent and requires a matching acknowledgement',async()=>{
  const id=crypto.randomUUID(),config={url:'https://host.example/agent-host/launch/model/grant',model:'fixture',apiKey:'studio-agent',studioGateway:true},options={workMode:'plan',disabledAgentTools:['fetch_url']};
  const module={ccall:(name,result,types,args)=>{
    const request=JSON.parse(args[0]);assert.equal(request.operation,'prompt');assert.equal(request.requestId,id);assert.deepEqual(request.llmConfig,config);assert.equal(request.workMode,'plan');assert.deepEqual(request.disabledAgentTools,['fetch_url']);
    module.doraStudioAgentEvent(JSON.stringify({kind:'command',sessionId:1,sequence:0,requestId:id,payload:JSON.stringify({success:true,sessionId:1,taskId:12})}));
  }};
  const source=create(module,1);
  try{assert.equal(await source.requestPrompt('make a game',options,config,id,new AbortController().signal),12);}
  finally{source.close();}
});
test('questionnaire response remains bound to its answers and trusted model configuration',async()=>{
  const id=crypto.randomUUID(),config={url:'https://host.example/agent-host/launch/model/grant',model:'fixture',apiKey:'studio-agent',studioGateway:true},answers=[{questionId:'style',status:'answered',selectedOptionIds:['arcade']}];
  const module={ccall:(name,result,types,args)=>{const request=JSON.parse(args[0]);assert.equal(request.operation,'questionnaire-respond');assert.equal(request.questionnaireId,9);assert.deepEqual(request.answers,answers);assert.deepEqual(request.llmConfig,config);module.doraStudioAgentEvent(JSON.stringify({kind:'command',sessionId:1,sequence:0,requestId:id,payload:'{"success":true,"taskId":12}'}));}};
  const source=create(module,1);
  try{assert.equal(await source.requestQuestionnaire('respond',9,answers,config,id,new AbortController().signal),12);}
  finally{source.close();}
});
test('successful author persistence explicitly resumes original Agent task admission',async()=>{
  const module={ccall:(name,result,types,args)=>{
    const request=JSON.parse(args[0]);assert.equal(request.operation,'resume');
    module.doraStudioAgentEvent(JSON.stringify({kind:'command',sessionId:1,sequence:0,requestId:request.requestId,payload:'{"success":true}'}));
  }};
  const source=create(module,1);
  try{await source.releaseQuiescence(new AbortController().signal);}
  finally{source.close();}
});
test('original Agent tool request returns only its bound browser compiler result',async()=>{
  const requests=[],module={ccall:(name,result,types,args)=>requests.push(JSON.parse(args[0]))};
  let runs=0;
  const source=create(module,1,async input=>{runs++;assert.equal(input.file,'/user/studio-project/main.ts');return {success:true,luaCode:'return true'};});
  try{
    module.doraStudioAgentEvent(JSON.stringify({kind:'tool-request',sessionId:1,sequence:0,requestId:'studio-tool-1-1',payload:JSON.stringify({operation:'transpile-ts',file:'/user/studio-project/main.ts',content:'export {}',projectRoot:'/user/studio-project'})}));
    await new Promise(resolve=>setTimeout(resolve,0));
    assert.equal(runs,1);assert.deepEqual(requests,[{operation:'tool-result',sessionId:1,requestId:'studio-tool-1-1',result:{success:true,luaCode:'return true'}}]);
  }finally{source.close();}
});
test('tool requests cannot escape the dedicated project root',()=>{
  const module={ccall:()=>{}},source=create(module,1,async()=>({success:true,luaCode:'x'}));
  try{assert.throws(()=>module.doraStudioAgentEvent(JSON.stringify({kind:'tool-request',sessionId:1,sequence:0,requestId:'studio-tool-1-1',payload:JSON.stringify({operation:'transpile-ts',file:'/user/studio-project/../secret.ts',content:'x',projectRoot:'/user/studio-project'})})),/Invalid Agent tool input/);assert.equal(module.doraStudioAgentEvent,undefined);}
  finally{source.close();}
});
test('original Agent cancellation stops its browser build without returning a late tool result',async()=>{
  const requests=[],module={ccall:(name,result,types,args)=>requests.push(JSON.parse(args[0]))};
  let aborted=false;
  const source=create(module,1,async(input,signal)=>new Promise(resolve=>{
    signal.addEventListener('abort',()=>{aborted=true;resolve({success:false,message:'late build'});},{once:true});
  }));
  try{
    module.doraStudioAgentEvent(JSON.stringify({kind:'tool-request',sessionId:1,sequence:0,requestId:'studio-tool-1-2',payload:JSON.stringify({operation:'transpile-ts',file:'/user/studio-project/main.ts',content:'export {}',projectRoot:'/user/studio-project'})}));
    module.doraStudioAgentEvent(JSON.stringify({kind:'tool-cancel',sessionId:1,sequence:0,requestId:'studio-tool-1-2',payload:'{}'}));
    await new Promise(resolve=>setTimeout(resolve,0));
    assert.equal(aborted,true);assert.deepEqual(requests,[]);
  }finally{source.close();}
});
test('original Agent preview callback returns bounded metadata and cancellation suppresses late captures',async()=>{
  const requests=[],module={ccall:(name,result,types,args)=>requests.push(JSON.parse(args[0]))};
  const input={operation:'preview-game',file:'/user/studio-project/main.lua',content:'{"entry":"main.ts","captureAtSeconds":[0.5]}',projectRoot:'/user/studio-project'};
  const source=create(module,1,async()=>({success:true,resultJSON:'{"success":true,"files":[".agent/vision/1-1.png"]}'}));
  try{
    module.doraStudioAgentEvent(JSON.stringify({kind:'tool-request',sessionId:1,sequence:0,requestId:'studio-tool-1-3',payload:JSON.stringify(input)}));
    await new Promise(resolve=>setTimeout(resolve,0));
    assert.deepEqual(requests,[{operation:'tool-result',sessionId:1,requestId:'studio-tool-1-3',result:{success:true,resultJSON:'{"success":true,"files":[".agent/vision/1-1.png"]}'}}]);
  }finally{source.close();}
  const late=[],module2={ccall:(name,result,types,args)=>late.push(JSON.parse(args[0]))};
  let aborted=false;
  const source2=create(module2,1,async(_input,signal)=>new Promise(resolve=>signal.addEventListener('abort',()=>{aborted=true;resolve({success:true,resultJSON:'late'});},{once:true})));
  try{
    module2.doraStudioAgentEvent(JSON.stringify({kind:'tool-request',sessionId:1,sequence:0,requestId:'studio-tool-1-4',payload:JSON.stringify(input)}));
    module2.doraStudioAgentEvent(JSON.stringify({kind:'tool-cancel',sessionId:1,sequence:0,requestId:'studio-tool-1-4',payload:'{}'}));
    await new Promise(resolve=>setTimeout(resolve,0));
    assert.equal(aborted,true);assert.deepEqual(late,[]);
  }finally{source2.close();}
});
test('original Agent Lua and Teal build callbacks require a bound source and bounded code reply',async()=>{
  for(const extension of ['lua','tl']){
    const results=[],module={ccall:(name,result,types,args)=>results.push(JSON.parse(args[0]))};
    const input={operation:'build-script',file:`/user/studio-project/main.${extension}`,content:'print(1)',projectRoot:'/user/studio-project'};
    const source=create(module,1,async()=>({success:true,luaCode:extension==='lua'?'':'-- [tl]: main.tl\nprint(1)'}));
    try{
      module.doraStudioAgentEvent(JSON.stringify({kind:'tool-request',sessionId:1,sequence:0,requestId:'studio-tool-1-5',payload:JSON.stringify(input)}));
      await new Promise(resolve=>setTimeout(resolve,0));
      assert.equal(results.length,1);assert.equal(results[0].result.success,true);assert.equal(results[0].result.luaCode,extension==='lua'?'':'-- [tl]: main.tl\nprint(1)');
    }finally{source.close();}
  }
});
