import test from 'node:test';
import assert from 'node:assert/strict';
import {build} from 'esbuild';
const bundle=await build({entryPoints:['apps/web/src/agent-wasm-host.ts'],bundle:true,write:false,format:'esm',platform:'node'});
const {installAgentWasmHost:install}=await import('data:text/javascript;base64,'+Buffer.from(bundle.outputFiles[0].text).toString('base64'));
test('capture returns bound current bytes only after a successful quiet snapshot',async()=>{
  const previousWindow=globalThis.window,previousLocation=globalThis.location;
  globalThis.window=new EventTarget();globalThis.location={origin:'https://host.example'};
  let quiet=false,reads=0,persisted=0;
  const bytes=new Uint8Array([0,255,128]);
  const detail={success:true,session:{id:1,projectRoot:'/user/studio-project',title:'test',kind:'main',rootSessionId:1,memoryScope:'main',workMode:'code',status:'IDLE',createdAt:1,updatedAt:1},messages:[],steps:[],relatedSessions:[],hasActivePlan:false};
  const module={
    ccall(name,result,types,args){
      const request=JSON.parse(args[0]);assert.equal(request.operation,'quiesce');quiet=true;
      module.doraStudioAgentEvent(JSON.stringify({kind:'snapshot',sessionId:1,sequence:0,requestId:request.requestId,payload:JSON.stringify({...detail,studioQuiescence:{success:true,quiescent:true,pending:[]}})}));
    },
    doraSyncUserStorage:async()=>{persisted++;},
    FS:{lstat:path=>({mode:path.endsWith('.bin')?1:2,size:3}),isDir:mode=>mode===2,isFile:mode=>mode===1,readdir:()=>['.agent','asset.bin'],readFile(){assert.equal(quiet,true);reads++;return bytes;}}
  };
  const host=install(module,{postMessage(){}},'https://studio.example',{projectId:'p',generation:'g',sessionId:1,projectRoot:'/user/studio-project'});
  try{
    const captured=await host.captureProject(new AbortController().signal);
    assert.deepEqual(captured,{projectId:'p',generation:'g',sessionId:1,reconciliationRequired:true,files:[{path:'asset.bin',bytes}]});
    captured.files[0].bytes[0]=99;assert.equal(bytes[0],0);
    assert.equal(reads,1);assert.equal(persisted,0);
    const again=await host.captureProject(new AbortController().signal);assert.equal(again.files[0].bytes[0],0);
  }finally{
    host.close();
    if(previousWindow===undefined)delete globalThis.window;else globalThis.window=previousWindow;
    if(previousLocation===undefined)delete globalThis.location;else globalThis.location=previousLocation;
  }
});
test('host setup failure and pagehide release only their callback ownership',()=>{
  const previousWindow=globalThis.window,previousLocation=globalThis.location;
  globalThis.window=new EventTarget();globalThis.location={origin:'https://host.example'};
  const module={ccall:()=>{}},binding={projectId:'p',generation:'g',sessionId:1};
  try {
    assert.throws(()=>install(module,{},'https://host.example',binding));
    assert.equal(module.doraStudioAgentEvent,undefined);
    const host=install(module,{postMessage(){}},'https://studio.example',binding);
    assert.equal(typeof module.doraStudioAgentEvent,'function');
    window.dispatchEvent(new Event('pagehide'));
    assert.equal(module.doraStudioAgentEvent,undefined);
    host.close();
    const replacement=()=>{};module.doraStudioAgentEvent=replacement;
    host.close();assert.equal(module.doraStudioAgentEvent,replacement);
  } finally {
    if(previousWindow===undefined)delete globalThis.window;else globalThis.window=previousWindow;
    if(previousLocation===undefined)delete globalThis.location;else globalThis.location=previousLocation;
  }
});
test('host rejects duplicate persistence and closing aborts an outstanding operation',async()=>{
  const previousWindow=globalThis.window,previousLocation=globalThis.location;
  globalThis.window=new EventTarget();globalThis.location={origin:'https://host.example'};
  let synced=false;
  const module={ccall:()=>{},doraSyncUserStorage:async()=>{synced=true;}};
  const host=install(module,{postMessage(){}},'https://studio.example',{projectId:'p',generation:'g',sessionId:1});
  try {
    const pending=host.persist(new AbortController().signal);
    await assert.rejects(host.persist(new AbortController().signal),/already in progress/);
    host.close();
    await assert.rejects(pending,/closed/);
    assert.equal(synced,false);
    await assert.rejects(host.persist(new AbortController().signal),/closed/);
  } finally {
    host.close();
    if(previousWindow===undefined)delete globalThis.window;else globalThis.window=previousWindow;
    if(previousLocation===undefined)delete globalThis.location;else globalThis.location=previousLocation;
  }
});
test('project capture owns the operation gate and never reads before quiescence',async()=>{
  const previousWindow=globalThis.window,previousLocation=globalThis.location;
  globalThis.window=new EventTarget();globalThis.location={origin:'https://host.example'};
  let read=false;
  const module={ccall:()=>{},FS:{lstat(){read=true;throw Error('must not read');}},doraSyncUserStorage:async()=>{}};
  const host=install(module,{postMessage(){}},'https://studio.example',{projectId:'p',generation:'g',sessionId:1,projectRoot:'/user/studio-project'});
  try{
    const pending=host.captureProject(new AbortController().signal);
    await assert.rejects(host.captureProject(new AbortController().signal),/unavailable/);
    await assert.rejects(host.persist(new AbortController().signal),/already in progress/);
    host.close();await assert.rejects(pending,/closed/);
    assert.equal(read,false);
    await assert.rejects(host.captureProject(new AbortController().signal),/unavailable/);
  }finally{
    host.close();
    if(previousWindow===undefined)delete globalThis.window;else globalThis.window=previousWindow;
    if(previousLocation===undefined)delete globalThis.location;else globalThis.location=previousLocation;
  }
});
