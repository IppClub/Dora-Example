import test from 'node:test';
import assert from 'node:assert/strict';
import {build} from 'esbuild';
const output=await build({entryPoints:[new URL('../apps/web/src/cloud-merge-apply.ts',import.meta.url).pathname],bundle:true,write:false,platform:'browser',format:'esm'});
const {applyCloudMerge}=await import(`data:text/javascript;base64,${Buffer.from(output.outputFiles[0].text).toString('base64')}`);
test('merge application binds current identity and local revision then requests atomic checkpoint and cloud rebase',async t=>{
 const original=globalThis.fetch;t.after(()=>{globalThis.fetch=original;});const signal=new AbortController().signal;
 const base={version:1,projectId:'game',revision:0,entry:'init.lua',files:[{path:'init.lua',kind:'text',text:'base'}]},local={...base,revision:2},remote={...base,files:[{path:'init.lua',kind:'text',text:'remote'}]};
 const preview={accountId:'a',projectId:'game',localRevision:2,baseCloudRevision:1,remoteCloudRevision:3,base,local,remote};let revision=2,saves=0,args;
 const store={async load(){return {name:'project',snapshot:{...local,revision}};},async save(...values){saves++;args=values;return {snapshot:values[1]};}};
 globalThis.fetch=async()=>Response.json({version:1,account:{accountId:'a'}});
 const result=await applyCloudMerge(store,preview,new Map(),undefined,signal);assert.equal(result.snapshot.files[0].text,'remote');assert.equal(result.snapshot.revision,3);
 assert.deepEqual(args.slice(2),[2,true,undefined,undefined,{accountId:'a',expectedCloudRevision:1,cloudRevision:3}]);
 revision=3;await assert.rejects(applyCloudMerge(store,preview,new Map(),undefined,signal),/Local project changed/);assert.equal(saves,1);
 revision=2;globalThis.fetch=async()=>Response.json({version:1,account:{accountId:'b'}});await assert.rejects(applyCloudMerge(store,preview,new Map(),undefined,signal),/Account changed/);assert.equal(saves,1);
 const controller=new AbortController();controller.abort();await assert.rejects(applyCloudMerge(store,preview,new Map(),undefined,controller.signal),error=>error.name==='AbortError');assert.equal(saves,1);
});
