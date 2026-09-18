import test from 'node:test';
import assert from 'node:assert/strict';
import {build} from 'esbuild';
const result=await build({entryPoints:[new URL('../apps/web/src/session-client.ts',import.meta.url).pathname],bundle:true,write:false,platform:'browser',format:'esm'});
const {loadSession}=await import(`data:text/javascript;base64,${Buffer.from(result.outputFiles[0].text).toString('base64')}`);
test('session client distinguishes anonymous from failure and strictly bounds identity responses',async t=>{
 const original=globalThis.fetch;t.after(()=>{globalThis.fetch=original;});
 const signal=new AbortController().signal;
 globalThis.fetch=async(path,options)=>{
  assert.equal(path,'/api/session');assert.equal(options.redirect,'error');assert.equal(options.cache,'no-store');assert.equal(options.credentials,'same-origin');
  return Response.json({version:1,account:{accountId:'用户😀'}});
 };
 assert.equal(await loadSession(signal),'用户😀');
 globalThis.fetch=async()=>new Response(null,{status:401});assert.equal(await loadSession(signal),null);
 for(const body of [{version:1,account:{accountId:'a',token:'secret'}},{version:1,account:{accountId:'\ud800'}},{version:1,account:{accountId:''}},{version:2,account:{accountId:'a'}}]){
  globalThis.fetch=async()=>Response.json(body);await assert.rejects(loadSession(signal),/Invalid session/);
 }
 let cancelled=false;
 globalThis.fetch=async()=>new Response(new ReadableStream({start(controller){controller.enqueue(new Uint8Array(4097));},cancel(){cancelled=true;}}));
 await assert.rejects(loadSession(signal),/too large/);assert.equal(cancelled,true);
 globalThis.fetch=async()=>new Response(new Uint8Array([0xff]));await assert.rejects(loadSession(signal));
 globalThis.fetch=async()=>new Response(null,{status:503});await assert.rejects(loadSession(signal),/unavailable/);
 const controller=new AbortController();controller.abort();globalThis.fetch=()=>{throw new Error('must not fetch');};
 await assert.rejects(loadSession(controller.signal),error=>error.name==='AbortError');
});
