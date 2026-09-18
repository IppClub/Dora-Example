import test from 'node:test';
import assert from 'node:assert/strict';
import {build} from 'esbuild';
const built=await build({entryPoints:['apps/web/src/agent-host-runtime.ts'],bundle:true,write:false,format:'esm',platform:'node'});
const {prepareAgentHostRuntime:prepare}=await import('data:text/javascript;base64,'+Buffer.from(built.outputFiles[0].text).toString('base64'));
test('runtime setup rejects reuse and cancels before storage admission',async()=>{
  const oldWindow=globalThis.window,oldLocation=globalThis.location;
  globalThis.window=new EventTarget();globalThis.location={origin:'https://host.example'};
  try {
    const module={ccall(){}},parent={postMessage(){}};
    const config={version:1,parentOrigin:'https://studio.example',accountId:'a',projectId:'p',generation:'g',projectRoot:'/game',title:'Title'};
    const runtime=prepare(module,parent,config);
    assert.throws(()=>prepare(module,parent,config),/already configured/);
    const stopped=assert.rejects(runtime.ready,/closed/);
    runtime.close();
    await stopped;await assert.rejects(runtime.storageId,/closed before storage/);
    assert.equal(module.doraStudioAgentEvent,undefined);
    assert.throws(()=>prepare(module,parent,config),/already configured/);
  }finally{
    if(oldWindow===undefined)delete globalThis.window;else globalThis.window=oldWindow;
    if(oldLocation===undefined)delete globalThis.location;else globalThis.location=oldLocation;
  }
});
