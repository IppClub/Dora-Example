import test from 'node:test';
import assert from 'node:assert/strict';
import {build} from 'esbuild';
const bundle=await build({entryPoints:['apps/web/src/workspace-agent.ts'],bundle:true,write:false,format:'esm',platform:'node',plugins:[{name:'host-boundaries',setup(build){
 build.onResolve({filter:/^\.\/(agent-launch-client|agent-host-frame)$/},args=>({path:args.path,namespace:'mock'}));
 build.onLoad({filter:/.*/,namespace:'mock'},args=>({contents:args.path.endsWith('agent-launch-client')?'export const requestAgentLaunch=(...args)=>globalThis.agentHarness.request(...args);export const revokeAgentLaunch=(...args)=>globalThis.agentHarness.revoke(...args);':'export const mountAgentHostFrame=(...args)=>globalThis.agentHarness.mount(...args);'}));
}}]});
const {startWorkspaceAgent,AgentStartupFailure}=await import('data:text/javascript;base64,'+Buffer.from(bundle.outputFiles[0].text).toString('base64'));
test('workspace startup owns successful session until explicit retirement, not later abort',async()=>{
 const calls=[];const signal=new AbortController();const controller={};
 globalThis.agentHarness={request:async()=>({projectId:'p'}),revoke:async()=>calls.push('revoke'),mount:()=>({ready:Promise.resolve({controller}),close:()=>calls.push('force'),persistAndClose:async()=>calls.push('persist')})};
 const binding=await startWorkspaceAgent({},'p','https://host.test',signal.signal);
 signal.abort();assert.deepEqual(calls,[]);assert.equal(binding.controller,controller);
 await binding.retirement.run();assert.deepEqual(calls,['persist','revoke']);
});
test('failed initialization closes host and retains retry when revocation fails',async()=>{
 const calls=[];let fail=true;
 globalThis.agentHarness={request:async()=>({projectId:'p'}),revoke:async()=>{calls.push('revoke');if(fail)throw Error('offline');},mount:()=>({ready:Promise.reject(Error('init')),close:()=>calls.push('force')})};
 let failure;try{await startWorkspaceAgent({},'p','https://host.test',new AbortController().signal);}catch(e){failure=e;}
 assert.ok(failure instanceof AgentStartupFailure);assert.equal(failure.cleanupPending,true);
 assert.deepEqual(calls,['force','revoke']);fail=false;await failure.retryCleanup();await failure.retryCleanup();
 assert.deepEqual(calls,['force','revoke','revoke']);
});
test('cancel after provisioning still revokes with a fresh signal and never mounts',async()=>{
 const signal=new AbortController();let revoked=false;
 globalThis.agentHarness={request:async()=>{signal.abort();return {projectId:'p'};},mount:()=>{throw Error('must not mount');},revoke:async(_launch,_origin,cleanupSignal)=>{assert.equal(cleanupSignal.aborted,false);revoked=true;}};
 await assert.rejects(startWorkspaceAgent({},'p','https://host.test',signal.signal),e=>e instanceof AgentStartupFailure&&!e.cleanupPending);
 assert.equal(revoked,true);
});
