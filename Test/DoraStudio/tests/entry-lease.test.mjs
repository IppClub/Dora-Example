import test from 'node:test';
import assert from 'node:assert/strict';
import { createEntryLease } from '../packages/agent-contracts/dist/entry-lease.js';

const active = () => false;

function entry() {
  const status = {success:true,running:false,runId:0};
  let stops = 0;
  return {status,get stops(){return stops;},getCurrentEntryStatus:()=>({...status}),
    stop(){stops++;status.running=false;return true;},
    start(){status.runId++;status.running=true;}};
}

test('entry lease leaves a manually started game running', async () => {
  const lease = createEntryLease(), runtime = entry();
  runtime.start();
  await assert.rejects(lease.acquireEntryLease('A',runtime,active),/user game is running/);
  assert.equal(runtime.stops,0);
  assert.equal(runtime.status.running,true);
  assert.equal(lease.ownsEntryLease('A',runtime),false);
  runtime.stop();
  await lease.acquireEntryLease('B',runtime,active);
});

test('a competing command waits for cleanup and a cancelled waiter leaves ownership intact', async () => {
  const lease = createEntryLease(), runtime = entry();
  await lease.acquireEntryLease('A',runtime,active);
  lease.recordEntryLeaseRun('A',runtime);runtime.start();
  assert.equal(lease.ownsEntryLease('A',runtime),true);

  let cancelled = false;
  const cancelledWaiter = lease.acquireEntryLease('B',runtime,()=>cancelled);
  cancelled = true;
  await assert.rejects(cancelledWaiter,/request cancelled/);
  assert.equal(lease.ownsEntryLease('A',runtime),true);
  assert.equal(runtime.stops,0);

  let acquired = false;
  const waiting = lease.acquireEntryLease('C',runtime,active).then(()=>{acquired=true;});
  await Promise.resolve();
  assert.equal(acquired,false);
  lease.releaseEntryLease('B',runtime);
  assert.equal(runtime.stops,0);
  lease.releaseEntryLease('A',runtime);
  await waiting;
  lease.recordEntryLeaseRun('C',runtime);runtime.start();
  assert.equal(lease.ownsEntryLease('C',runtime),true);
  assert.equal(runtime.stops,1);
  lease.releaseEntryLease('C',runtime);
});

test('late cleanup cannot stop a newer run and independent hosts do not share ownership', async () => {
  const lease = createEntryLease(), runtime = entry();
  await lease.acquireEntryLease('A',runtime,active);lease.recordEntryLeaseRun('A',runtime);runtime.start();
  runtime.start();
  assert.equal(lease.ownsEntryLease('A',runtime),false);
  const other = createEntryLease(), otherRuntime = entry();
  await other.acquireEntryLease('B',otherRuntime,active);
  lease.releaseEntryLease('A',runtime);
  assert.equal(runtime.stops,0);
  await lease.acquireEntryLease('A',entry(),active);
});

test('cleanup failure is returned and releases ownership for subsequent commands', async () => {
  const lease = createEntryLease(), runtime = entry();
  await lease.acquireEntryLease('A',runtime,active);lease.recordEntryLeaseRun('A',runtime);runtime.start();
  runtime.stop=()=>false;
  assert.match(lease.releaseEntryLease('A',runtime),/entry refused to stop/);
  runtime.status.running=false;
  await lease.acquireEntryLease('B',runtime,active);
});
