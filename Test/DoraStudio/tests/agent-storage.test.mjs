import test from 'node:test';
import assert from 'node:assert/strict';
import {build} from 'esbuild';
const result=await build({entryPoints:['apps/web/src/agent-storage.ts'],bundle:true,write:false,format:'esm',platform:'browser'});
const {agentStorageId,acquireAgentStorage}=await import('data:text/javascript;base64,'+Buffer.from(result.outputFiles[0].text).toString('base64'));
test('Agent storage is stable and separated by account, project and Studio origin',async()=>{
  const id=await agentStorageId('https://studio.example','account','project');
  assert.match(id,/^agent-[a-f0-9]{64}$/);
  assert.equal(await agentStorageId('https://studio.example','account','project'),id);
  for(const args of [['https://other.example','account','project'],['https://studio.example','other','project'],['https://studio.example','account','other']])assert.notEqual(await agentStorageId(...args),id);
  assert.notEqual(await agentStorageId('https://studio.example','a:b','c'),await agentStorageId('https://studio.example','a','b:c'));
});
test('Agent storage rejects ambiguous origins and empty identities',async()=>{
  for(const origin of ['null','file:///tmp','https://studio.example/','https://user@studio.example','https://studio.example/path'])await assert.rejects(agentStorageId(origin,'a','p'));
  await assert.rejects(agentStorageId('https://studio.example','','p'));
  await assert.rejects(agentStorageId('https://studio.example','a',''));
});
test('Agent storage refuses unsafe IDs or unavailable exclusive locking',async()=>{
  await assert.rejects(acquireAgentStorage('preview-'+'a'.repeat(64),null),/Invalid/);
  await assert.rejects(acquireAgentStorage('agent-'+'a'.repeat(64),null),/unavailable/);
});
