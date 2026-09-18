import test from 'node:test';
import assert from 'node:assert/strict';
import {build} from 'esbuild';
const bundle=await build({entryPoints:['../Assets/Script/Lib/Agent/Runtime/SessionEvents.ts'],bundle:true,write:false,format:'esm',platform:'node',banner:{js:'const error=message=>{throw new Error(message);};'}});
const {subscribeSessionPatches,publishSessionPatch,captureSessionSnapshot}=await import('data:text/javascript;base64,'+Buffer.from(bundle.outputFiles[0].text).toString('base64'));
test('session patch listeners are session-scoped and unsubscribe is idempotent',()=>{
  const seen=[];
  const stop=subscribeSessionPatches(1,payload=>seen.push(payload));
  publishSessionPatch(2,'other');publishSessionPatch(1,'first');
  stop();stop();publishSessionPatch(1,'later');
  assert.deepEqual(seen,['first']);
});
test('a failed patch observer does not prevent delivery to other observers',()=>{
  let received=0;
  const bad=subscribeSessionPatches(3,()=>{throw new Error('observer failure');});
  const good=subscribeSessionPatches(3,()=>{received++;});
  try {assert.equal(publishSessionPatch(3,'{}'),1);assert.equal(received,1);} finally {bad();good();}
});
test('snapshot cursor includes events before subscription and subsequent events continue it',()=>{
  publishSessionPatch(10,'before');
  const snapshot=captureSessionSnapshot(10,()=>'{"success":true}');
  assert.equal(snapshot.sequence,1);
  const seen=[];
  const stop=subscribeSessionPatches(10,(payload,sequence)=>seen.push({payload,sequence}));
  publishSessionPatch(10,'after');stop();
  assert.deepEqual(seen,[{payload:'after',sequence:2}]);
});
test('reads that publish or return asynchronous results cannot produce a stable snapshot',()=>{
  assert.throws(()=>captureSessionSnapshot(11,()=>{publishSessionPatch(11,'during');return '{}';}),/changed/);
  assert.throws(()=>captureSessionSnapshot(11,()=>Promise.resolve('{}')),/changed/);
  assert.equal(captureSessionSnapshot(11,()=>'{}').sequence,1);
});
