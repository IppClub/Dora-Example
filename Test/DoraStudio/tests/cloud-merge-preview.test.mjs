import test from 'node:test';
import assert from 'node:assert/strict';
import {build} from 'esbuild';
const output=await build({entryPoints:[new URL('../apps/web/src/cloud-merge-preview.ts',import.meta.url).pathname],bundle:true,write:false,platform:'browser',format:'esm'});
const {previewCloudMerge}=await import(`data:text/javascript;base64,${Buffer.from(output.outputFiles[0].text).toString('base64')}`);
test('merge preview loads exact cloud baseline, merges latest and rejects pending or changed bindings',async t=>{
 const original=globalThis.fetch;t.after(()=>{globalThis.fetch=original;});
 const base={version:1,projectId:'game',revision:0,entry:'init.lua',files:[{path:'init.lua',kind:'text',text:'a\nb\nc\n'}]},local={...base,revision:2,files:[{path:'init.lua',kind:'text',text:'A\nb\nc\n'}]},remote={...base,files:[{path:'init.lua',kind:'text',text:'a\nb\nC\n'}]};
 let binding={accountId:'a',projectId:'game',cloudRevision:1},calls=0;
 const store={async cloudSync(){return structuredClone(binding);}},signal=new AbortController().signal;
 globalThis.fetch=async(path,options)=>{calls++;assert.equal(options.headers['X-Studio-Account'],'a');return Response.json({version:1,cloudRevision:path.endsWith('/versions/1')?1:3,updatedAt:1000,name:'Game',snapshot:path.endsWith('/versions/1')?base:remote});};
 const preview=await previewCloudMerge(store,'a',local,signal);assert.equal(preview.remoteCloudRevision,3);assert.equal(preview.plan.files[0].text,'A\nb\nC\n');assert.equal(calls,2);
 binding.pending={requestId:'pending'};await assert.rejects(previewCloudMerge(store,'a',local,signal),/Resolve/);assert.equal(calls,2);delete binding.pending;
 globalThis.fetch=async()=>Response.json({version:1,cloudRevision:2,updatedAt:1000,name:'Game',snapshot:base});await assert.rejects(previewCloudMerge(store,'a',local,signal),/revision mismatch/);
 globalThis.fetch=async(path)=>{binding.cloudRevision=2;return Response.json({version:1,cloudRevision:path.endsWith('/versions/1')?1:3,updatedAt:1000,name:'Game',snapshot:base});};
 await assert.rejects(previewCloudMerge(store,'a',local,signal),/binding changed/);
});
