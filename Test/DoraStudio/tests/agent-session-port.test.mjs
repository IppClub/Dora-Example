import test from 'node:test';
import assert from 'node:assert/strict';
import {MessageChannel} from 'node:worker_threads';
import {build} from 'esbuild';
import {createHash} from 'node:crypto';
const bundle=await build({stdin:{contents:"export {connectAgentSessionPort} from './apps/web/src/agent-session-port'; export {serveAgentSessionPort} from './apps/web/src/agent-session-port-host';",resolveDir:process.cwd(),loader:'ts'},bundle:true,write:false,format:'esm',platform:'node'});
const {connectAgentSessionPort:connect,serveAgentSessionPort:serve}=await import('data:text/javascript;base64,'+Buffer.from(bundle.outputFiles[0].text).toString('base64'));
const binding={projectId:'p',generation:'g',sessionId:1};
const detail={success:true,session:{id:1,projectRoot:'/game',title:'test',kind:'main',rootSessionId:1,memoryScope:'main',workMode:'code',status:'IDLE',createdAt:1,updatedAt:1},messages:[],steps:[],relatedSessions:[],hasActivePlan:false};
const snapshot={type:'snapshot',version:1,...binding,sequence:0,payload:JSON.stringify(detail)};
const update=sequence=>({type:'patch',version:1,...binding,sequence,payload:JSON.stringify({name:'AgentSessionPatch',sessionId:1,hasActivePlan:true})});
test('capture deadline closes the connection and cancels unanswered host work',{timeout:30000},async()=>{
 const {port1,port2}=new MessageChannel();let hostSignal,finish;
 const gate=new Promise(resolve=>{finish=resolve;});
 const host=serve(port2,binding,{subscribe:()=>()=>{},capture:()=>snapshot},{persist:async()=>{},captureProject:async signal=>{hostSignal=signal;await gate;return {...binding,reconciliationRequired:true,files:[]};}});
 const client=await connect(port1,binding,new AbortController().signal,1000);
 try{
  const started=performance.now();
  await assert.rejects(client.captureProject(),/closed/);
  assert.ok(performance.now()-started>=19500,'must use the production operation deadline');
  assert.equal(client.controller.closed,true);
  for(let i=0;i<50&&!host.closed;i++)await new Promise(resolve=>setTimeout(resolve,2));
  assert.equal(host.closed,true);assert.equal(hostSignal.aborted,true);
  await assert.rejects(client.persist(),/unavailable/);
 }finally{finish();client.close();host.close();}
});
test('invalid capture responses retire the client and reject the pending operation',async()=>{
 for(const variant of ['generation','completion','path','request']){
  const {port1,port2}=new MessageChannel();
  port2.on('message',message=>{
    if(message.type==='subscribe')port2.postMessage({...snapshot,canCaptureProject:true});
    if(message.type==='capture-project'){
      const capture={...binding,reconciliationRequired:true,files:[{path:'a.bin',bytes:new Uint8Array([1])}]};
      if(variant==='generation')capture.generation='stale';
      if(variant==='completion')capture.reconciliationRequired=false;
      if(variant==='path')capture.files[0].path='../escape';
      port2.postMessage({type:'project-captured',version:1,...binding,requestId:variant==='request'?crypto.randomUUID():message.requestId,success:true,capture});
    }
  });
  const client=await connect(port1,binding,new AbortController().signal,1000);
  try{
    await assert.rejects(client.captureProject(),/closed/);
    assert.equal(client.controller.closed,true);
    await assert.rejects(client.captureProject(),/unavailable/);
  }finally{client.close();port2.close();}
 }
});
test('closing a capture aborts its host work and suppresses a late successful result',async()=>{
 const {port1,port2}=new MessageChannel();let finish,started,hostSignal;
 const gate=new Promise(resolve=>{finish=resolve;}),entered=new Promise(resolve=>{started=resolve;});
 const host=serve(port2,binding,{subscribe:()=>()=>{},capture:()=>snapshot},{persist:async()=>{},captureProject:async signal=>{hostSignal=signal;started();await gate;return {...binding,reconciliationRequired:true,files:[]};}});
 const client=await connect(port1,binding,new AbortController().signal,1000);
 try{
  const pending=client.captureProject();await entered;
  client.close();await assert.rejects(pending,/closed/);
  // Host cleanup is asynchronous because unsubscribe crosses the port.
  for(let i=0;i<50&&!host.closed;i++)await new Promise(resolve=>setTimeout(resolve,2));
  assert.equal(host.closed,true);assert.equal(hostSignal.aborted,true);
  finish();assert.equal(client.controller.closed,true);
 }finally{finish();client.close();host.close();}
});
test('client capture receives validated bytes and shares the persistence gate',async()=>{
 const {port1,port2}=new MessageChannel();let finish;
 const gate=new Promise(resolve=>{finish=resolve;});
 const host=serve(port2,binding,{subscribe:()=>()=>{},capture:()=>snapshot},{persist:async()=>{},captureProject:async()=>{await gate;return {...binding,reconciliationRequired:true,files:[{path:'a.bin',bytes:new Uint8Array([255])}]};}});
 const client=await connect(port1,binding,new AbortController().signal,1000);
 try{
  assert.equal(client.canCaptureProject,true);
  const pending=client.captureProject();
  await assert.rejects(client.persist(),/progress/);
  await assert.rejects(client.captureProject(),/unavailable/);
  finish();const captured=await pending;assert.equal(captured.files[0].bytes[0],255);assert.equal(captured.reconciliationRequired,true);
  await client.persist();
 }finally{finish();client.close();host.close();}
});
test('host capture capability validates result identity and suppresses privileged failures',async()=>{
 const {port1,port2}=new MessageChannel();let foreign=false;
 const host=serve(port2,binding,{subscribe:()=>()=>{},capture:()=>snapshot},{persist:async()=>{},captureProject:async()=>({...binding,projectId:foreign?'secret-project':'p',reconciliationRequired:true,files:[{path:'a.bin',bytes:new Uint8Array([255,0])}]})});
 const next=()=>new Promise(resolve=>port1.once('message',resolve));
 try{
  let received=next();port1.postMessage({type:'subscribe',version:1,...binding});
  assert.equal((await received).canCaptureProject,true);
  received=next();port1.postMessage({type:'capture-project',version:1,...binding,requestId:crypto.randomUUID()});
  const result=await received;assert.equal(result.success,true);assert.deepEqual([...result.capture.files[0].bytes],[255,0]);
  foreign=true;received=next();port1.postMessage({type:'capture-project',version:1,...binding,requestId:crypto.randomUUID()});
  const denied=await received;assert.equal(denied.success,false);assert.equal(denied.capture,undefined);assert.equal(JSON.stringify(denied).includes('secret-project'),false);
 }finally{host.close();port1.close();}
});
test('project sync verifies bytes, waits for installation, and excludes simultaneous persistence',async()=>{
  const {port1,port2}=new MessageChannel();let finish,received,calls=0;
  const gate=new Promise(resolve=>{finish=resolve;});
  const host=serve(port2,binding,{subscribe:()=>()=>{},capture:()=>snapshot},{persist:async()=>{},syncProject:async value=>{calls++;received=value;await gate;}});
  const client=await connect(port1,binding,new AbortController().signal,1000);
  const bytes=new TextEncoder().encode('-- source only');
  const envelope={version:1,kind:'dora-agent-author-snapshot',projectId:'p',revision:2,entry:'init.lua',files:[{path:'init.lua',kind:'text',bytes}],manifest:[{path:'init.lua',kind:'text',size:bytes.length,sha256:createHash('sha256').update(bytes).digest('hex')}]};
  try{
    assert.equal(client.canSyncProject,true);
    const bad=structuredClone(envelope);bad.files[0].bytes[0]=0;
    await assert.rejects(client.syncProject(bad),/synchronization failed/);assert.equal(calls,0);
    const pending=client.syncProject(envelope);let completed=false;pending.then(()=>{completed=true;});
    await assert.rejects(client.persist(),/progress/);
    await new Promise(resolve=>setTimeout(resolve,20));assert.equal(completed,false);
    finish();await pending;assert.equal(calls,1);assert.equal(received.revision,2);assert.equal(received.files[0].text,'-- source only');
    assert.equal(client.controller.closed,false);
  }finally{finish();client.close();host.close();}
});
test('dedicated host port acknowledges one bound prompt without accepting a foreign grant or echoing host errors',async()=>{
  const {port1,port2}=new MessageChannel(),requestId=crypto.randomUUID();let calls=0;
  const options={workMode:'plan',disabledAgentTools:['fetch_url']};
  const host=serve(port2,binding,{subscribe:()=>()=>{},capture:()=>snapshot},{persist:async()=>{},sendPrompt:async(prompt,grant,id,received)=>{calls++;assert.equal(prompt,'make a game');assert.equal(grant,'grant');assert.equal(id,requestId);assert.deepEqual(received,options);return 17;}});
  const client=await connect(port1,binding,new AbortController().signal,1000);
  try{
    assert.equal(client.canSendPrompt,true);
    assert.equal(await client.sendPrompt('make a game','grant',requestId,options),17);
    await assert.rejects(client.sendPrompt('make a game','../foreign',crypto.randomUUID(),options),/invalid/);
    await assert.rejects(client.sendPrompt('make a game','grant',crypto.randomUUID(),{workMode:'code',disabledAgentTools:['unknown']}),/invalid/);
    assert.equal(calls,1);
  }finally{client.close();host.close();}
});
test('dedicated port publishes validated model queue state without changing the Agent transcript',async()=>{
  const {port1,port2}=new MessageChannel();let queue={version:1,state:'idle'},listener;
  const modelQueue={getSnapshot:()=>queue,subscribe:value=>{listener=value;return()=>{listener=undefined;}}};
  const host=serve(port2,binding,{subscribe:()=>()=>{},capture:()=>snapshot},{persist:async()=>{},modelQueue});
  const client=await connect(port1,binding,new AbortController().signal,1000);
  try{
    assert.deepEqual(client.modelQueue.getSnapshot(),{version:1,state:'idle'});
    const changed=new Promise(resolve=>{const stop=client.modelQueue.subscribe(()=>{stop();resolve();});});
    queue={version:1,state:'queued',queuedAt:123,position:2};listener();await changed;
    assert.deepEqual(client.modelQueue.getSnapshot(),queue);
    assert.equal(client.controller.closed,false);
  }finally{client.close();host.close();}
});
test('dedicated host port forwards one validated questionnaire response',async()=>{
  const {port1,port2}=new MessageChannel(),requestId=crypto.randomUUID(),answers=[{questionId:'style',status:'answered',selectedOptionIds:['arcade']}];let calls=0;
  const host=serve(port2,binding,{subscribe:()=>()=>{},capture:()=>snapshot},{persist:async()=>{},handleQuestionnaire:async(action,id,value,grant,request)=>{calls++;assert.equal(action,'respond');assert.equal(id,9);assert.deepEqual(value,answers);assert.equal(grant,'grant');assert.equal(request,requestId);return 17;}});
  const client=await connect(port1,binding,new AbortController().signal,1000);
  try{assert.equal(client.canHandleQuestionnaire,true);assert.equal(await client.handleQuestionnaire('respond',9,answers,'grant',requestId),17);await assert.rejects(client.handleQuestionnaire('respond',0,answers,'grant',crypto.randomUUID()),/invalid/);assert.equal(calls,1);}
  finally{client.close();host.close();}
});
test('dedicated host port stops one running task and captures committed live files',async()=>{
  const {port1,port2}=new MessageChannel();let stops=0,captures=0;
  const host=serve(port2,binding,{subscribe:()=>()=>{},capture:()=>snapshot},{
    stopTask:async requestId=>{stops++;assert.match(requestId,/^[0-9a-f-]{36}$/i);},
    captureLiveProject:async()=>{captures++;return {...binding,reconciliationRequired:true,files:[{path:'tetris.ts',bytes:new TextEncoder().encode('export const game = true;')}]};},
  });
  const client=await connect(port1,binding,new AbortController().signal,1000);
  try{
    assert.equal(client.canStopTask,true);assert.equal(client.canCaptureLiveProject,true);
    const capture=await client.captureLiveProject();assert.equal(captures,1);assert.equal(new TextDecoder().decode(capture.files[0].bytes),'export const game = true;');
    await client.stopTask(crypto.randomUUID());assert.equal(stops,1);assert.equal(client.controller.closed,false);
  }finally{client.close();host.close();}
});
const previewArtifact={buildId:'preview',projectId:'p',revision:0,compilerVersion:'test',entry:'init.lua',files:[{path:'init.lua',kind:'text',text:'print(1)'}],sourceMaps:{},sha256:'0'.repeat(64)};
test('bound original Agent preview request reaches one frontend Player handler and returns PNG bytes',async()=>{
 const {port1,port2}=new MessageChannel();
 const host=serve(port2,binding,{subscribe:()=>()=>{},capture:()=>snapshot});
 const client=await connect(port1,binding,new AbortController().signal,1000);
 try{
  let calls=0;
  client.setPreviewHandler(async(artifact,times)=>{calls++;assert.equal(artifact.projectId,'p');assert.deepEqual(times,[0.5]);return [{png:Uint8Array.from([137,80,78,71,13,10,26,10]),width:100,height:50,elapsedSeconds:0.6}];});
  const frames=await host.requestPreview(previewArtifact,[0.5],new AbortController().signal);
  assert.equal(calls,1);assert.deepEqual([...frames[0].png],[137,80,78,71,13,10,26,10]);
  assert.equal(client.controller.closed,false);
 }finally{client.close();host.close();}
});
test('original Agent preview cancellation aborts the frontend handler and ignores its late frame',async()=>{
 const {port1,port2}=new MessageChannel(),host=serve(port2,binding,{subscribe:()=>()=>{},capture:()=>snapshot});
 const client=await connect(port1,binding,new AbortController().signal,1000),abort=new AbortController();
 let entered,hostSignal,release;
 const started=new Promise(resolve=>entered=resolve),gate=new Promise(resolve=>release=resolve);
 try{
  client.setPreviewHandler(async(_artifact,_times,signal)=>{hostSignal=signal;entered();await gate;return [{png:Uint8Array.from([137,80,78,71,13,10,26,10]),width:1,height:1,elapsedSeconds:1}];});
  const pending=host.requestPreview(previewArtifact,[0.5],abort.signal);await started;
  abort.abort(new Error('Agent command stopped'));await assert.rejects(pending,/Agent command stopped/);
  for(let i=0;i<50&&!hostSignal.aborted;i++)await new Promise(resolve=>setTimeout(resolve,2));
  assert.equal(hostSignal.aborted,true);release();await new Promise(resolve=>setTimeout(resolve,0));
  assert.equal(client.controller.closed,false);
 }finally{release?.();client.close();host.close();}
});
test('foreign preview requests retire the bound Agent port before invoking Player',async()=>{
 const {port1,port2}=new MessageChannel();
 port2.on('message',message=>{if(message.type==='subscribe')port2.postMessage(snapshot);});
 const client=await connect(port1,binding,new AbortController().signal,1000);
 let calls=0;client.setPreviewHandler(async()=>{calls++;return [];});
 try{
  port2.postMessage({type:'preview-request',version:1,...binding,projectId:'foreign',requestId:crypto.randomUUID(),artifact:previewArtifact,captureAtSeconds:[0.5]});
  for(let i=0;i<50&&!client.controller.closed;i++)await new Promise(resolve=>setTimeout(resolve,2));
  assert.equal(client.controller.closed,true);assert.equal(calls,0);
 }finally{client.close();port2.close();}
});
test('persistence is opt-in and reports host completion or failure without closing the session',async()=>{
  for(const mode of ['readonly','success','failure']) {
    const {port1,port2}=new MessageChannel();let calls=0;
    const host=serve(port2,binding,{subscribe:()=>()=>{},capture:()=>snapshot},mode==='readonly'?undefined:{persist:async()=>{calls++;if(mode==='failure')throw Error('private host detail');}});
    const client=await connect(port1,binding,new AbortController().signal,1000);
    try {
      assert.equal(client.canPersist,mode!=='readonly');
      if(mode==='success')await client.persist();
      else await assert.rejects(client.persist(),mode==='readonly'?/unavailable/:/host retained/);
      assert.equal(calls,mode==='readonly'?0:1);
      assert.equal(client.controller.closed,false);
    }finally{client.close();host.close();}
  }
});
test('dedicated port initializes from snapshot, applies events and retires on gaps',async()=>{
  const {port1,port2}=new MessageChannel();
  try {
    port2.once('message',request=>{assert.equal(request.type,'subscribe');port2.postMessage(snapshot);});
    const {controller,close}=await connect(port1,binding,new AbortController().signal,1000);
    const next=()=>new Promise(resolve=>{const stop=controller.subscribe(()=>{stop();resolve();});});
    let changed=next();port2.postMessage(update(1));await changed;
    assert.equal(controller.state.hasActivePlan,true);
    changed=next();port2.postMessage(update(3));await changed;
    assert.equal(controller.needsResync,true);
    assert.equal(controller.sequence,1);
    close();
  } finally {port1.close();port2.close();}
});
test('timeout, abort and patch-before-snapshot reject startup',async()=>{
  for(const mode of ['timeout','abort','order']){
    const {port1,port2}=new MessageChannel(),abort=new AbortController();
    try {
      const pending=connect(port1,binding,abort.signal,20);
      if(mode==='abort')abort.abort();
      if(mode==='order')port2.postMessage(update(1));
      await assert.rejects(pending);
    } finally {port1.close();port2.close();}
  }
});

test('host and client share a source snapshot cursor and close releases the source',async()=>{
  const {port1,port2}=new MessageChannel();
  let emit,unsubscribed=0;
  const host=serve(port2,binding,{subscribe:listener=>{emit=listener;listener(update(1).payload,1);return ()=>unsubscribed++;},capture:()=>({payload:JSON.stringify(detail),sequence:1})});
  try {
    const connection=await connect(port1,binding,new AbortController().signal,1000);
    assert.equal(connection.controller.sequence,1);
    assert.equal(connection.controller.state.hasActivePlan,false,'buffered event already included by the snapshot must not be replayed');
    const changed=new Promise(resolve=>{const stop=connection.controller.subscribe(()=>{stop();resolve();});});
    emit(update(2).payload,2);await changed;
    assert.equal(connection.controller.state.hasActivePlan,true);
    const stopped=new Promise(resolve=>{const stop=connection.controller.subscribe(()=>{stop();resolve();});});
    host.close();await stopped;
    assert.equal(connection.controller.closed,true);
    assert.equal(unsubscribed,1);
    host.close();assert.equal(unsubscribed,1);
    connection.close();
  } finally {host.close();port1.close();port2.close();}
});

test('client close explicitly unsubscribes the host source',async()=>{
  const {port1,port2}=new MessageChannel();
  let released;
  const release=new Promise(resolve=>released=resolve);
  const host=serve(port2,binding,{subscribe:()=>()=>released(),capture:()=>({payload:JSON.stringify(detail),sequence:0})});
  try {
    const connection=await connect(port1,binding,new AbortController().signal,1000);
    connection.close();
    await release;
    assert.equal(host.closed,true);
  }finally{host.close();port1.close();port2.close();}
});

test('events during asynchronous capture follow the resolved snapshot in order',async()=>{
  const {port1,port2}=new MessageChannel();
  let emit,finish,started;
  const capturing=new Promise(resolve=>started=resolve);
  const host=serve(port2,binding,{subscribe:listener=>{emit=listener;return ()=>{};},capture:()=>{started();return new Promise(resolve=>finish=resolve);}});
  try {
    const pending=connect(port1,binding,new AbortController().signal,1000);
    await capturing;
    emit(update(1).payload,1);emit(update(2).payload,2);
    finish({payload:JSON.stringify(detail),sequence:1});
    const connection=await pending;
    if(connection.controller.sequence<2)await new Promise(resolve=>{const stop=connection.controller.subscribe(()=>{stop();resolve();});});
    assert.equal(connection.controller.sequence,2);
    assert.equal(connection.controller.state.hasActivePlan,true);
    connection.close();
  }finally{host.close();port1.close();port2.close();}
});

test('closing while capturing aborts the source and ignores its late result',async()=>{
  const {port1,port2}=new MessageChannel();
  let finish,started,signal,released=0;
  const capturing=new Promise(resolve=>started=resolve);
  const host=serve(port2,binding,{subscribe:()=>()=>released++,capture:input=>{signal=input;started();return new Promise(resolve=>finish=resolve);}});
  try {
    const pending=connect(port1,binding,new AbortController().signal,1000);
    const rejected=assert.rejects(pending);
    await capturing;host.close();
    assert.equal(signal.aborted,true);
    finish({payload:JSON.stringify(detail),sequence:0});
    await rejected;assert.equal(released,1);
  }finally{host.close();port1.close();port2.close();}
});
