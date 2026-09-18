import test from 'node:test';
import assert from 'node:assert/strict';
import {build} from 'esbuild';
const built=await build({entryPoints:['apps/web/src/agent-launch-client.ts'],bundle:true,write:false,format:'esm',platform:'node'});
const {requestAgentLaunch:request,revokeAgentLaunch:revoke}=await import('data:text/javascript;base64,'+Buffer.from(built.outputFiles[0].text).toString('base64'));
test('launch client pins host and project, rejects late/oversize responses and never retries POST',async()=>{
  const oldFetch=globalThis.fetch,oldLocation=globalThis.location;
  globalThis.location={origin:'https://studio.example'};
  const id='12345678-1234-1234-1234-123456789abc';
  const valid={version:1,projectId:'p',generation:id,expiresAt:Date.now()+60000,url:`https://host.example/agent-host/${id}/index.html`};
  let value=valid,calls=0,status=201;
  globalThis.fetch=async(url,options)=>{
    calls++;assert.equal(url.href,'https://studio.example/api/projects/p/agent-launch');assert.equal(options.method,'POST');assert.equal(options.body,undefined);
    assert.equal(options.redirect,'error');return new Response(JSON.stringify(value),{status});
  };
  try {
    const result=await request('p','https://host.example',new AbortController().signal);assert.equal(result.url,valid.url);assert.ok(Object.isFrozen(result));
    for(const change of [{projectId:'other'},{url:valid.url.replace('host.example','evil.example')},{url:valid.url+'?token=x'},{expiresAt:0}]){
      value={...valid,...change};await assert.rejects(request('p','https://host.example',new AbortController().signal));
    }
    value={...valid,extra:'x'.repeat(20000)};await assert.rejects(request('p','https://host.example',new AbortController().signal),/too large/);
    status=403;const before=calls;await assert.rejects(request('p','https://host.example',new AbortController().signal));assert.equal(calls,before+1);
    const abort=new AbortController();abort.abort();await assert.rejects(request('p','https://host.example',abort.signal));assert.equal(calls,before+1);
    const late=new AbortController();globalThis.fetch=async()=>{late.abort();return new Response(JSON.stringify(valid),{status:201});};
    await assert.rejects(request('p','https://host.example',late.signal));
  }finally{globalThis.fetch=oldFetch;if(oldLocation===undefined)delete globalThis.location;else globalThis.location=oldLocation;}
});
test('revocation uses the bound same-origin API and requires explicit cleanup confirmation',async()=>{
  const oldFetch=globalThis.fetch,oldLocation=globalThis.location;
  globalThis.location={origin:'https://studio.example'};
  const id='12345678-1234-1234-1234-123456789abc',launch={projectId:'p',url:`https://host.example/agent-host/${id}/index.html`};
  let calls=0,status=204;
  globalThis.fetch=async(url,options)=>{calls++;assert.equal(url.href,`https://studio.example/api/projects/p/agent-launch/${id}`);assert.equal(options.method,'DELETE');assert.equal(options.body,undefined);return new Response(null,{status});};
  try {
    await revoke(launch,'https://host.example',new AbortController().signal);
    status=403;await assert.rejects(revoke(launch,'https://host.example',new AbortController().signal),/not confirmed/);assert.equal(calls,2);
    await assert.rejects(revoke({...launch,url:launch.url+'?x=1'},'https://host.example',new AbortController().signal));assert.equal(calls,2);
    const aborted=new AbortController();aborted.abort();await assert.rejects(revoke(launch,'https://host.example',aborted.signal));assert.equal(calls,2);
  }finally{globalThis.fetch=oldFetch;if(oldLocation===undefined)delete globalThis.location;else globalThis.location=oldLocation;}
});
