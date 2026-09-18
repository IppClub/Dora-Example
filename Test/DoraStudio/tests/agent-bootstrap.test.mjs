import test from 'node:test';
import assert from 'node:assert/strict';
import {build} from 'esbuild';
const built=await build({entryPoints:['apps/web/src/agent-bootstrap.ts'],bundle:true,write:false,format:'esm',platform:'node'});
const {prepareAgentBootstrap}=await import('data:text/javascript;base64,'+Buffer.from(built.outputFiles[0].text).toString('base64'));
test('bootstrap waits for bound initialization and cleans invalid or timed out ownership',async()=>{
  const oldWindow=globalThis.window,oldLocation=globalThis.location;
  globalThis.window=new EventTarget();globalThis.location={origin:'https://host.example'};
  const messages=[],parent={postMessage:message=>messages.push(message)};
  const binding={projectId:'p',generation:'g',projectRoot:'/game'};
  try {
    const module={ccall(){}};
    const bootstrap=prepareAgentBootstrap(module,parent,'https://studio.example',binding);
    module.doraStudioAgentEvent(JSON.stringify({kind:'snapshot'}));assert.equal(messages.length,0);
    module.doraStudioAgentEvent(JSON.stringify({kind:'initialized',projectRoot:'/game',sessionId:7}));
    await bootstrap.ready;assert.equal(messages[0].sessionId,7);
    bootstrap.close();assert.equal(module.doraStudioAgentEvent,undefined);
    const invalid=prepareAgentBootstrap(module,parent,'https://studio.example',binding);
    const rejected=assert.rejects(invalid.ready,/Mismatched/);
    assert.throws(()=>module.doraStudioAgentEvent(JSON.stringify({kind:'initialized',projectRoot:'/other',sessionId:7})),/Mismatched/);
    await rejected;assert.equal(module.doraStudioAgentEvent,undefined);assert.equal(messages.length,1);
    const timed=prepareAgentBootstrap(module,parent,'https://studio.example',binding,10);
    await assert.rejects(timed.ready,/timed out/);assert.equal(module.doraStudioAgentEvent,undefined);
  } finally {
    if(oldWindow===undefined)delete globalThis.window;else globalThis.window=oldWindow;
    if(oldLocation===undefined)delete globalThis.location;else globalThis.location=oldLocation;
  }
});
