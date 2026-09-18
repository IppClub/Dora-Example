import test from 'node:test';
import assert from 'node:assert/strict';
import {build} from 'esbuild';
const output=await build({entryPoints:[new URL('../apps/web/src/cloud-project-sync.ts',import.meta.url).pathname],bundle:true,write:false,platform:'browser',format:'esm'});
const {startCloudUpload,resumeCloudUpload}=await import(`data:text/javascript;base64,${Buffer.from(output.outputFiles[0].text).toString('base64')}`);
test('cloud sync persists before dispatch and resumes the identical request after a lost receipt',async t=>{
 const original=globalThis.fetch;t.after(()=>{globalThis.fetch=original;});let record,prepares=0,confirmed=0;const bodies=[];
 const storage={async prepareCloudUpload(accountId,snapshot,requestId,name){prepares++;record=structuredClone({accountId,projectId:snapshot.projectId,cloudRevision:0,pending:{requestId,snapshot,name}});},async cloudSync(accountId){return record?.accountId===accountId?structuredClone(record):undefined;},async confirmCloudUpload(accountId,projectId,requestId,revision){assert.equal(requestId,record.pending.requestId);assert.equal(accountId,record.accountId);record={accountId,projectId,cloudRevision:revision};confirmed++;}};
 const snapshot={version:1,projectId:'game',revision:4,entry:'init.lua',files:[{path:'init.lua',kind:'text',text:'print(1)'}]},signal=new AbortController().signal;
 globalThis.fetch=async(_,options)=>{assert.ok(record.pending);bodies.push(options.body);throw new Error('response lost');};
 await assert.rejects(startCloudUpload(storage,'a',snapshot,signal,'俄罗斯方块'),/response lost/);assert.equal(confirmed,0);assert.equal(record.pending.name,'俄罗斯方块');
 snapshot.files[0].text='changed after request';
 await assert.rejects(resumeCloudUpload(storage,'b','game',signal),/matching pending/);assert.equal(bodies.length,1);
 globalThis.fetch=async(_,options)=>{bodies.push(options.body);const body=JSON.parse(options.body);return Response.json({version:1,projectId:'game',requestId:body.requestId,cloudRevision:1,replayed:true});};
 assert.deepEqual(await resumeCloudUpload(storage,'a','game',signal),{cloudRevision:1,localRevision:4,replayed:true});
 assert.equal(bodies[0],bodies[1]);assert.equal(JSON.parse(bodies[0]).name,'俄罗斯方块');assert.equal(prepares,1);assert.equal(confirmed,1);assert.equal(record.pending,undefined);
 const controller=new AbortController();controller.abort();await assert.rejects(startCloudUpload(storage,'a',snapshot,controller.signal),error=>error.name==='AbortError');assert.equal(prepares,1);
});
