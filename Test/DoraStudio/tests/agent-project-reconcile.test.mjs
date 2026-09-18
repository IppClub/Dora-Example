import test from 'node:test';
import assert from 'node:assert/strict';
import {build} from 'esbuild';
const bundle=await build({entryPoints:['apps/web/src/agent-project-reconcile.ts'],bundle:true,write:false,format:'esm',platform:'node'});
const {proposeAgentWriteback:propose}=await import('data:text/javascript;base64,'+Buffer.from(bundle.outputFiles[0].text).toString('base64'));
const baseline={version:1,projectId:'p',revision:3,entry:'init.lua',files:[{path:'init.lua',kind:'text',text:'return 1'},{path:'asset.txt',kind:'binary',bytes:new Uint8Array([255,0])}]};
const current=()=>baseline.files.map(f=>({path:f.path,bytes:f.kind==='text'?new TextEncoder().encode(f.text):new Uint8Array(f.bytes)}));
test('writeback proposes exact bytes without saving or inventing a revision',()=>{
 assert.equal(propose(baseline,baseline,current()).changed,false);
 const files=current();files[0].bytes=new TextEncoder().encode('\uFEFFreturn 2');
 const result=propose(baseline,baseline,files);
 assert.equal(result.changed,true);assert.equal(result.expectedRevision,3);assert.equal(result.snapshot.revision,3);
 assert.equal(result.snapshot.files[0].text,'\uFEFFreturn 2');
 assert.equal(result.snapshot.files[1].kind,'binary');
 files[1].bytes[0]=0;assert.equal(result.snapshot.files[1].bytes[0],255);
 assert.equal(propose(baseline,baseline,[files[0]]).snapshot.files.length,1);
});
test('writeback rejects concurrent author edits, missing entry and invalid payloads',()=>{
 assert.throws(()=>propose(baseline,{...baseline,revision:4},current()),/changed/);
 assert.throws(()=>propose(baseline,{...baseline,files:[{...baseline.files[0],text:'edited'},baseline.files[1]]},current()),/changed/);
 assert.throws(()=>propose(baseline,baseline,[]),/entry/);
 assert.throws(()=>propose(baseline,baseline,[...current(),current()[0]]),/Invalid/);
 assert.throws(()=>propose(baseline,baseline,[...current(),{path:'.agent/private',bytes:new Uint8Array()}]),/Invalid/);
 assert.throws(()=>propose(baseline,baseline,[{path:'init.lua',bytes:new Uint8Array([255])}]));
});
