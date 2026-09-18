import test from 'node:test';
import assert from 'node:assert/strict';
import {build} from 'esbuild';
const output=await build({entryPoints:[new URL('../apps/web/src/cloud-merge-resolution.ts',import.meta.url).pathname],bundle:true,write:false,platform:'browser',format:'esm'});
const {resolveCloudMerge}=await import(`data:text/javascript;base64,${Buffer.from(output.outputFiles[0].text).toString('base64')}`);
const text=(path,value)=>({path,kind:'text',text:value});
const snapshot=(files,entry='init.lua')=>({version:1,projectId:'game',revision:4,entry,files:[text('init.lua','print(1)'),...files]});
test('resolution requires explicit choices and preserves selected binary or deletion',()=>{
 const binary=value=>({path:'image.bin',kind:'binary',bytes:new Uint8Array([value])});
 const base=snapshot([binary(0),text('removed','base')]),local=snapshot([binary(1)]),remote=snapshot([binary(2),text('removed','remote')]);
 assert.throws(()=>resolveCloudMerge(base,local,remote,new Map()),/Unresolved/);
 const choices=new Map([['image.bin','remote'],['removed','local']]);
 const result=resolveCloudMerge(base,local,remote,choices);assert.equal(result.revision,5);assert.equal(result.files.some(file=>file.path==='removed'),false);
 const selected=result.files.find(file=>file.kind==='binary');assert.equal(selected.bytes[0],2);selected.bytes[0]=99;assert.equal(remote.files[1].bytes[0],2);
 choices.set('unknown','local');assert.throws(()=>resolveCloudMerge(base,local,remote,choices),/Unknown/);
});
test('entry decisions and structural validation cannot be bypassed by file choices',()=>{
 const base=snapshot([]),local=snapshot([text('left.lua','')],'left.lua'),remote=snapshot([text('right.lua','')],'right.lua');
 assert.throws(()=>resolveCloudMerge(base,local,remote,new Map()),/entry conflict/);
 assert.equal(resolveCloudMerge(base,local,remote,new Map(),'remote').entry,'right.lua');
 assert.throws(()=>resolveCloudMerge(base,snapshot([text('dir','')]),snapshot([text('dir/child','')]),new Map()),/structure/);
 assert.throws(()=>resolveCloudMerge(base,base,base,new Map(),'local'),/Unexpected/);
});
test('manual text and keep-both binary resolution retain exact content and reject destination collisions',()=>{
 const binary=value=>({path:'image.bin',kind:'binary',bytes:new Uint8Array([value])});
 const base=snapshot([text('script.lua','base'),binary(0)]),local=snapshot([text('script.lua','local'),binary(1)]),remote=snapshot([text('script.lua','remote'),binary(2)]);
 const choices=new Map([['script.lua',{kind:'text',text:'\ufeffcombined\r\n'}],['image.bin',{kind:'both',remotePath:'image-remote.bin'}]]);
 const result=resolveCloudMerge(base,local,remote,choices);
 assert.equal(result.files.find(file=>file.path==='script.lua').text,'\ufeffcombined\r\n');
 assert.deepEqual(Array.from(result.files.find(file=>file.path==='image.bin').bytes),[1]);
 assert.deepEqual(Array.from(result.files.find(file=>file.path==='image-remote.bin').bytes),[2]);
 for(const remotePath of ['../escape','image.bin','init.lua','script.lua/child']){
  choices.set('image.bin',{kind:'both',remotePath});assert.throws(()=>resolveCloudMerge(base,local,remote,choices));
 }
 choices.set('image.bin',{kind:'text',text:'not binary'});assert.throws(()=>resolveCloudMerge(base,local,remote,choices),/text files/);
});
