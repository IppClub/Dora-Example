import test from 'node:test';
import assert from 'node:assert/strict';
import {build} from 'esbuild';
const bundle=await build({entryPoints:['apps/web/src/agent-project-capture.ts'],bundle:true,write:false,format:'esm',platform:'node'});
const {decodeAgentProjectCapture:decode}=await import('data:text/javascript;base64,'+Buffer.from(bundle.outputFiles[0].text).toString('base64'));
const binding={projectId:'p',generation:'g',sessionId:1};
const capture=()=>({...binding,reconciliationRequired:true,files:[{path:'a.bin',bytes:new Uint8Array([0,255])}]});
test('capture decoder owns bytes and allows an empty current tree without claiming completion',()=>{
 const input=capture(),result=decode(input,binding);input.files[0].bytes[0]=9;
 assert.deepEqual([...result.files[0].bytes],[0,255]);
 assert.deepEqual(decode({...capture(),files:[]},binding).files,[]);
 assert.equal(result.reconciliationRequired,true);
});
test('capture decoder rejects foreign identity, false completion and unsafe file payloads',()=>{
 for(const change of [{projectId:'other'},{generation:'old'},{sessionId:2},{reconciliationRequired:false},{files:[...capture().files,...capture().files]}])assert.throws(()=>decode({...capture(),...change},binding));
 for(const path of ['../escape','.agent/state','/root','a/../b'])assert.throws(()=>decode({...capture(),files:[{path,bytes:new Uint8Array()}]},binding));
 assert.throws(()=>decode({...capture(),files:[{path:'a',bytes:[1,2]}]},binding));
 assert.throws(()=>decode({...capture(),files:[{path:'a',bytes:new Uint8Array(new SharedArrayBuffer(1))}]},binding));
 assert.throws(()=>decode({...capture(),files:Array(4097).fill(capture().files[0])},binding));
});
