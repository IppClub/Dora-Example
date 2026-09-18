import test from 'node:test';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {build} from 'esbuild';
const bundle=await build({entryPoints:['apps/web/src/agent-project-snapshot.ts'],bundle:true,write:false,format:'esm',platform:'node'});
const {prepareAgentProjectSnapshot:prepare,decodeAgentProjectSnapshot:decode}=await import('data:text/javascript;base64,'+Buffer.from(bundle.outputFiles[0].text).toString('base64'));
const sample=()=>({version:1,projectId:'p',revision:3,entry:'init.lua',files:[{path:'init.lua',kind:'text',text:'-- 中文\nerror("must not execute")'},{path:'Resources/a.bin',kind:'binary',bytes:new Uint8Array([0,255,128])}]});
test('author envelope preserves uncompiled source and binary bytes with independent ownership',async()=>{
 const input=sample(),pending=prepare(input,'p',new AbortController().signal);
 input.files[0].text='changed';input.files[1].bytes.fill(9);input.revision=4;
 const result=await pending;
 assert.equal(result.kind,'dora-agent-author-snapshot');assert.equal(result.revision,3);
 assert.equal(new TextDecoder().decode(result.files[0].bytes),sample().files[0].text);
 assert.deepEqual([...result.files[1].bytes],[0,255,128]);
 for(let i=0;i<result.files.length;i++)assert.equal(result.manifest[i].sha256,createHash('sha256').update(result.files[i].bytes).digest('hex'));
 assert.equal('url' in result.manifest[0],false);
});
test('receiver owns bytes, preserves BOM and rejects tampering or foreign envelopes',async()=>{
 const signal=new AbortController().signal;
 const input=sample();input.files[0].text='\ufeff'+input.files[0].text;
 const envelope=await prepare(input,'p',signal);
 const pending=decode(envelope,'p',signal);envelope.files[1].bytes.fill(7);
 assert.deepEqual(await pending,input);
 await assert.rejects(decode(envelope,'p',signal),/integrity/);
 for(const change of [e=>{e.projectId='other';},e=>{e.manifest.pop();},e=>{e.manifest[0].size++;},e=>{e.files[1].path=e.files[0].path;},e=>{e.files[0].path='../host';}]){
  const bad=await prepare(input,'p',signal);change(bad);await assert.rejects(decode(bad,'p',signal));
 }
 const abort=new AbortController(),valid=await prepare(input,'p',signal);
 const cancelled=decode(valid,'p',abort.signal);abort.abort();await assert.rejects(cancelled);
});
test('author envelope rejects foreign projects, unsafe paths and cancellation',async()=>{
 await assert.rejects(prepare(sample(),'other',new AbortController().signal));
 const bad=sample();bad.files[1].path='../Agent/Session.lua';await assert.rejects(prepare(bad,'p',new AbortController().signal));
 const abort=new AbortController();const pending=prepare(sample(),'p',abort.signal);abort.abort();await assert.rejects(pending);
 await assert.rejects(prepare(sample(),'p',abort.signal));
});
