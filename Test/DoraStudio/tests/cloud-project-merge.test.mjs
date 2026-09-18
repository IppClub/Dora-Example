import test from 'node:test';
import assert from 'node:assert/strict';
import {build} from 'esbuild';
const output=await build({entryPoints:[new URL('../apps/web/src/cloud-project-merge.ts',import.meta.url).pathname],bundle:true,write:false,platform:'browser',format:'esm'});
const {planCloudMerge}=await import(`data:text/javascript;base64,${Buffer.from(output.outputFiles[0].text).toString('base64')}`);
const text=(path,value)=>({path,kind:'text',text:value}),binary=(value)=>({path:'image.bin',kind:'binary',bytes:new Uint8Array(value)});
const snapshot=files=>({version:1,projectId:'game',revision:0,entry:'init.lua',files:[text('init.lua','print(1)'),...files]});
test('cloud merge combines independent file edits and deletions without aliasing inputs',()=>{
 const base=snapshot([text('a','base'),text('b','base'),text('gone','old')]);
 const local=snapshot([text('a','local'),text('b','base')]);
 const remote=snapshot([text('a','base'),text('b','remote'),text('gone','old')]);
 const plan=planCloudMerge(base,local,remote);assert.equal(plan.conflicts.length,0);assert.deepEqual(plan.validationErrors,[]);
 assert.deepEqual(plan.files.map(file=>[file.path,file.text]),[['a','local'],['b','remote'],['init.lua','print(1)']]);
 plan.files[0].text='mutated';assert.equal(local.files[1].text,'local');
});
test('cloud merge retains both binary/text sides and delete-edit conflicts',()=>{
 const base=snapshot([binary([0]),text('both','base'),text('removed','base')]);
 const local=snapshot([binary([1]),text('both','left')]);
 const remote=snapshot([binary([2]),text('both','right'),text('removed','changed')]);
 const plan=planCloudMerge(base,local,remote);assert.deepEqual(plan.conflicts.map(item=>item.path),['both','image.bin','removed']);
 assert.equal(plan.conflicts[2].local,null);assert.equal(plan.conflicts[2].remote.text,'changed');
 plan.conflicts[1].local.bytes[0]=99;assert.equal(local.files[1].bytes[0],1);
 assert.equal(planCloudMerge(base,local,local).conflicts.length,0);
});
test('cloud merge detects combined structural invalidity and incompatible entry changes',()=>{
 const base=snapshot([]),local=snapshot([text('dir','file')]),remote=snapshot([text('dir/child','file')]);
 assert.ok(planCloudMerge(base,local,remote).validationErrors.some(error=>error.includes('collision')));
 const left={...snapshot([text('left.lua','')]),entry:'left.lua'},right={...snapshot([text('right.lua','')]),entry:'right.lua'};
 assert.equal(planCloudMerge(base,left,right).entry,null);
 assert.throws(()=>planCloudMerge(base,left,{...right,projectId:'other'}),/Invalid/);
});
