import test from 'node:test';
import assert from 'node:assert/strict';
import {build} from 'esbuild';
const built=await build({entryPoints:['apps/web/src/byok-secret-client.ts'],bundle:true,write:false,format:'esm',platform:'browser'});
const {requestByokSecret}=await import(`data:text/javascript;base64,${Buffer.from(built.outputFiles[0].text).toString('base64')}`);
test('secret client sends once to same origin, requires consent and never follows redirects',async t=>{
 const originalFetch=globalThis.fetch,originalLocation=globalThis.location;
 t.after(()=>{globalThis.fetch=originalFetch;if(originalLocation===undefined)delete globalThis.location;else globalThis.location=originalLocation;});
 globalThis.location={origin:'https://studio.test'};const calls=[];
 globalThis.fetch=async(url,options)=>{calls.push({url:url.href,options});return new Response(JSON.stringify({version:1,available:true}));};
 const signal=new AbortController().signal,input={method:'PUT',expectedVersion:0,key:'fixture-secret',consent:true};
 assert.deepEqual(await requestByokSecret('owned',input,signal),{version:1,available:true});
 assert.equal(calls[0].url,'https://studio.test/api/byok/configurations/owned/secret');assert.equal(calls[0].options.redirect,'error');assert.equal(calls[0].options.credentials,'same-origin');
 assert.deepEqual(JSON.parse(calls[0].options.body),{expectedVersion:0,key:'fixture-secret',consent:true});
 await assert.rejects(requestByokSecret('owned',{...input,consent:false},signal),error=>error.code==='invalid');
 await assert.rejects(requestByokSecret('../other',input,signal),error=>error.code==='invalid');assert.equal(calls.length,1);
 globalThis.fetch=async()=>{calls.push({});throw new Error('secret-url-key');};
 await assert.rejects(requestByokSecret('owned',input,signal),error=>error.code==='uncertain'&&!error.message.includes('secret-url-key'));assert.equal(calls.length,2);
 globalThis.fetch=async()=>new Response('',{status:409});await assert.rejects(requestByokSecret('owned',input,signal),error=>error.code==='conflict');
 for(const value of [{version:0,available:true},{version:1,available:false},{version:1,available:true,key:'must not return'}]){
  globalThis.fetch=async()=>new Response(JSON.stringify(value));await assert.rejects(requestByokSecret('owned',input,signal),error=>error.code==='uncertain');
 }
 globalThis.fetch=async()=>new Response('x'.repeat(4097));await assert.rejects(requestByokSecret('owned',{method:'GET'},signal),error=>error.code==='unavailable');
 const aborted=new AbortController();aborted.abort();globalThis.fetch=async()=>{throw new Error('must not call');};await assert.rejects(requestByokSecret('owned',input,aborted.signal),error=>error.name==='AbortError');
});
