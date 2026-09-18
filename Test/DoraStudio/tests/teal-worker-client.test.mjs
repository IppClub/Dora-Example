import test from 'node:test';
import assert from 'node:assert/strict';
import { createTealWorkerBuild } from '../packages/agent-contracts/dist/teal-worker-client.js';
const request = {snapshot: {projectId: 'A', revision: 0}, path: 'main.lua'};
test('Teal worker client validates and copies structured diagnostics', async () => {
  let message, terminated = 0;
  const worker = {postMessage(value) {message = value;}, terminate() {terminated++;}};
  const pending = createTealWorkerBuild(() => worker, [])(request);
  const data = {id:message.id,type:'result',success:false,message:'type error', diagnostics:[
    {type:'type',path:'main.lua',line:'1',column:2,message:'wrong type'},
  ]};
  worker.onmessage({data});
  assert.equal(terminated, 0);
  data.diagnostics[0].line = 1;
  worker.onmessage({data});
  data.diagnostics[0].message = 'mutated';
  assert.equal((await pending).diagnostics[0].message, 'wrong type');
  assert.equal(terminated, 1);
});
test('Teal worker client rejects foreign output, copies input and terminates after completion', async () => {
  let message, terminated = 0;
  const worker = {postMessage(value) {message = value;}, terminate() {terminated++;}};
  const build = createTealWorkerBuild(() => worker, []);
  const pending = build(request);
  assert.notEqual(message.snapshot, request.snapshot);
  worker.onmessage({data: {id:'foreign', type:'result', success:true}});
  assert.equal(terminated, 0);
  worker.onmessage({data: {id:message.id, type:'result', success:false}});
  assert.equal(terminated, 0);
  worker.onmessage({data: {id:message.id, type:'result', success:true}});
  assert.equal((await pending).success, true);
  assert.equal(terminated, 1);
});
test('Teal worker client cancellation and timeout release workers', async () => {
  for (const mode of ['abort', 'timeout']) {
    let terminated = 0;
    const signal = new AbortController();
    const build = createTealWorkerBuild(() => ({postMessage() {}, terminate() {terminated++;}}), [], {timeoutMs: 5});
    const pending = build({...request, signal:signal.signal});
    if (mode === 'abort') signal.abort();
    assert.equal((await pending).interrupted, true);
    assert.equal(terminated, 1);
  }
});
