import test from 'node:test';
import assert from 'node:assert/strict';
import {build} from 'esbuild';
const result=await build({entryPoints:['apps/web/src/runtime-capture.ts'],bundle:true,write:false,platform:'browser',format:'esm'});
const {createRuntimeCapture}=await import(`data:text/javascript;base64,${Buffer.from(result.outputFiles[0].text).toString('base64')}`);
test('engine capture adapter cancels pending work and removes late temporary images',async()=>{
  let id, reads=0;const removed=[];
  const module={ccall(name,type,types,args){id=args[0];},FS:{readFile(){reads++;return new Uint8Array(0);},unlink(path){removed.push(path);}}};
  const capture=createRuntimeCapture(module),controller=new AbortController();
  const pending=capture(controller.signal);controller.abort();
  await assert.rejects(pending,/取消/);
  module.doraCaptureComplete(id,true);
  assert.equal(reads,0);assert.deepEqual(removed,[`/tmp/dora-studio-capture-${id}.png`]);
  module.doraCaptureComplete('../project',true);module.doraCaptureComplete(id+100,true);
  assert.equal(removed.length,1);
});
test('engine capture adapter reports failure and cleans invalid PNG output',async()=>{
  let id;const removed=[];
  const module={ccall(name,type,types,args){id=args[0];},FS:{readFile(){return new Uint8Array(0);},unlink(path){removed.push(path);}}};
  const capture=createRuntimeCapture(module);
  for(const success of [false,true]) {
    const pending=capture(new AbortController().signal);module.doraCaptureComplete(id,success);
    await assert.rejects(pending);assert.equal(removed.length,id);
  }
});
