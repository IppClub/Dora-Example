import test from 'node:test';
import assert from 'node:assert/strict';
import {build} from 'esbuild';
const output=await build({entryPoints:[new URL('../apps/web/src/cloud-project-client.ts',import.meta.url).pathname],bundle:true,write:false,platform:'browser',format:'esm'});
const {uploadCloudProject,loadCloudProject,listCloudProjects,listCloudHistory}=await import(`data:text/javascript;base64,${Buffer.from(output.outputFiles[0].text).toString('base64')}`);
test('cloud client binds receipts, preserves binary data, cancels and never retries uncertain uploads',async t=>{
 const original=globalThis.fetch;t.after(()=>{globalThis.fetch=original;});const signal=new AbortController().signal;
 const snapshot={version:1,projectId:'a/b',revision:7,entry:'init.lua',files:[{path:'init.lua',kind:'text',text:'\ufeffprint(1)\r\n'},{path:'raw.bin',kind:'binary',bytes:new Uint8Array([0,255])}]};let wire,calls=0;
 globalThis.fetch=async(path,options)=>{calls++;assert.equal(path,'/api/projects/a%2Fb');assert.equal(options.credentials,'same-origin');assert.equal(options.redirect,'error');wire=JSON.parse(options.body);return Response.json({version:1,projectId:'a/b',requestId:'request',cloudRevision:1,replayed:false});};
 assert.deepEqual(await uploadCloudProject('a',snapshot,0,'request',signal,'雨夜游戏'),{cloudRevision:1,replayed:false});assert.equal(wire.name,'雨夜游戏');assert.equal(wire.snapshot.files[1].base64,'AP8=');
 globalThis.fetch=async()=>Response.json({version:1,cloudRevision:1,updatedAt:1000,name:wire.name,snapshot:wire.snapshot});
 assert.deepEqual(await loadCloudProject('a/b',signal),{cloudRevision:1,updatedAt:1000,name:'雨夜游戏',snapshot});
 globalThis.fetch=async()=>Response.json({version:1,projectId:'other',requestId:'request',cloudRevision:1,replayed:false});await assert.rejects(uploadCloudProject('a',snapshot,0,'request',signal,'雨夜游戏'),/receipt/);
 calls=0;globalThis.fetch=async()=>{calls++;throw new Error('lost response');};await assert.rejects(uploadCloudProject('a',snapshot,0,'request',signal,'雨夜游戏'),/lost response/);assert.equal(calls,1);
 globalThis.fetch=async()=>new Response(null,{status:409});await assert.rejects(uploadCloudProject('a',snapshot,0,'request',signal,'雨夜游戏'),error=>error.status===409);
 const controller=new AbortController();controller.abort();globalThis.fetch=()=>{throw new Error('must not fetch');};await assert.rejects(loadCloudProject('a/b',controller.signal),error=>error.name==='AbortError');
});
test('cloud list binds expected account and rejects duplicate rows or a stuck cursor',async t=>{
 const original=globalThis.fetch;t.after(()=>{globalThis.fetch=original;});const signal=new AbortController().signal;
 globalThis.fetch=async(path,options)=>{assert.equal(options.headers['X-Studio-Account'],encodeURIComponent('用户'));return Response.json({version:1,items:[{projectId:'a',name:'项目 A',cloudRevision:1,updatedAt:1}],nextCursor:null});};
 assert.deepEqual(await listCloudProjects(signal,'','用户'),{items:[{projectId:'a',name:'项目 A',cloudRevision:1,updatedAt:1}],nextCursor:null});
 globalThis.fetch=async()=>Response.json({version:1,items:[{projectId:'a',name:'\u0000',cloudRevision:1,updatedAt:1}],nextCursor:null});await assert.rejects(listCloudProjects(signal,'','用户'),/name/);
 globalThis.fetch=async(path,options)=>{assert.equal(options.headers['X-Studio-Account'],encodeURIComponent('用户'));return Response.json({version:1,items:[],nextCursor:null});};
 assert.deepEqual(await listCloudProjects(signal,'','用户'),{items:[],nextCursor:null});
 for(const page of [{items:[{projectId:'a',name:'A',cloudRevision:1,updatedAt:1},{projectId:'a',name:'A',cloudRevision:2,updatedAt:2}],nextCursor:null},{items:[{projectId:'a',name:'A',cloudRevision:1,updatedAt:1}],nextCursor:'a'}]){
  globalThis.fetch=async()=>Response.json({version:1,...page});await assert.rejects(listCloudProjects(signal,'a','用户'));
 }
});
test('cloud history binds identity and rejects invalid pages before offering timestamped downloads',async t=>{
 const original=globalThis.fetch;t.after(()=>{globalThis.fetch=original;});const signal=new AbortController().signal;
 globalThis.fetch=async(path,options)=>{
  assert.equal(path,'/api/projects/a%2Fb/history?limit=20&after=20');
  assert.equal(options.headers['X-Studio-Account'],encodeURIComponent('用户'));
  return Response.json({version:1,items:[{cloudRevision:21,updatedAt:2100},{cloudRevision:22,updatedAt:2200}],nextCursor:null});
 };
 assert.deepEqual(await listCloudHistory('a/b','用户',signal,20),{items:[{cloudRevision:21,updatedAt:2100},{cloudRevision:22,updatedAt:2200}],nextCursor:null});
 for(const page of [
  {items:[{cloudRevision:20,updatedAt:1}],nextCursor:null},
  {items:[{cloudRevision:22,updatedAt:1},{cloudRevision:21,updatedAt:2}],nextCursor:null},
  {items:[{cloudRevision:21,updatedAt:1},{cloudRevision:21,updatedAt:2}],nextCursor:null},
  {items:[{cloudRevision:21.5,updatedAt:1}],nextCursor:null},
  {items:[],nextCursor:21},
  {items:[{cloudRevision:21,updatedAt:1}],nextCursor:22},
  {items:Array.from({length:21},(_,i)=>({cloudRevision:i+21,updatedAt:i+1})),nextCursor:null},
 ]){
  globalThis.fetch=async()=>Response.json({version:1,...page});
  await assert.rejects(listCloudHistory('a/b','用户',signal,20),/history/);
 }
 globalThis.fetch=()=>{throw new Error('must not fetch');};
 await assert.rejects(listCloudHistory('a/b','用户',signal,-1),/cursor/);
 const controller=new AbortController();controller.abort();
 await assert.rejects(listCloudHistory('a/b','用户',controller.signal),error=>error.name==='AbortError');
});
