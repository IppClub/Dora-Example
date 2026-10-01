import test from 'node:test';
import assert from 'node:assert/strict';
import {build} from 'esbuild';
const result=await build({entryPoints:[new URL('../apps/web/src/ModelAllowance.tsx',import.meta.url).pathname],bundle:true,write:false,format:'esm',platform:'browser',loader:{'.css':'empty'}});
const {loadAllowance}=await import(`data:text/javascript;base64,${Buffer.from(result.outputFiles[0].text).toString('base64')}`);
test('allowance reads reject redirects, bound streamed bytes and do not dispatch cancelled requests',async t=>{
 const original=globalThis.fetch;t.after(()=>{globalThis.fetch=original;});
 let calls=0,cancelled=false;
 globalThis.fetch=async(url,options)=>{calls++;assert.equal(options.redirect,'error');assert.equal(options.credentials,'same-origin');assert.equal(options.cache,'no-store');return new Response(new ReadableStream({pull(controller){controller.enqueue(new Uint8Array(65537));},cancel(){cancelled=true;}}));};
 await assert.rejects(loadAllowance('grant',new AbortController().signal),/Oversize/);assert.equal(cancelled,true);assert.equal(calls,1);
 const aborted=new AbortController();aborted.abort();await assert.rejects(loadAllowance('grant',aborted.signal));assert.equal(calls,1);
 await assert.rejects(loadAllowance('../foreign',new AbortController().signal));assert.equal(calls,1);
 globalThis.fetch=async()=>new Response(new Uint8Array([0xff]));await assert.rejects(loadAllowance('grant',new AbortController().signal));
 const body={version:1,currency:'CNY',unit:'nano-CNY',funding:'platform',grantId:'grant',state:'available',available:'5',api:{spent:'0',reserved:'0',limit:'0'},account:{spent:'0',reserved:'0',limit:'5'},grant:{spent:'0',reserved:'0',limit:'5'}};
 globalThis.fetch=async()=>Response.json(body);assert.equal((await loadAllowance('grant',new AbortController().signal)).available,'5');
 globalThis.fetch=async()=>Response.json({...body,grantId:'other'});await assert.rejects(loadAllowance('grant',new AbortController().signal),/Invalid allowance/);
});
