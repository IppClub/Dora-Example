import test from 'node:test';
import assert from 'node:assert/strict';
import {build} from 'esbuild';
const bundle=await build({entryPoints:['apps/web/src/agent-file-commit-queue.ts'],bundle:true,write:false,format:'esm',platform:'node'});
const {decodeAgentFileCommitQueue:decode}=await import('data:text/javascript;base64,'+Buffer.from(bundle.outputFiles[0].text).toString('base64'));
const queue=()=>({reconciliationRequired:true,overflowed:false,batches:[{version:1,taskId:1,checkpointId:2,checkpointSeq:3,changes:[{path:'main.lua',op:'write'}]}]});
test('queue decoder owns metadata and keeps incomplete-history semantics',()=>{
 const input=queue(),result=decode(input);input.batches[0].changes[0].path='changed';
 assert.equal(result.batches[0].changes[0].path,'main.lua');assert.equal(result.reconciliationRequired,true);
 assert.deepEqual(decode({...queue(),batches:{}}).batches,[]);
 assert.equal(decode({...queue(),overflowed:true}).overflowed,true);
});
test('queue decoder rejects invalid identities, duplicate paths and false completion',()=>{
 for(const mutate of [q=>q.reconciliationRequired=false,q=>q.batches.push(q.batches[0]),q=>q.batches[0].taskId=-1,q=>q.batches[0].changes[0].path='../host',q=>q.batches[0].changes.push(q.batches[0].changes[0]),q=>q.batches[0].changes[0].op='execute',q=>q.batches={hidden:true}]){
  const input=queue();mutate(input);assert.throws(()=>decode(input));
 }
});
