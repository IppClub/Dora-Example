import test from 'node:test';
import assert from 'node:assert/strict';
import { createEntryLease } from '../packages/agent-contracts/dist/entry-lease.js';

function entry() {
  const status = {success:true,running:false,runId:0};
  let stops = 0;
  return {status,get stops(){return stops;},getCurrentEntryStatus:()=>({...status}),
    stop(){stops++;status.running=false;return true;},
    start(){status.runId++;status.running=true;}};
}
test('original entry lease excludes concurrent Agent tools and never stops a manual game', () => {
  const lease = createEntryLease(), runtime = entry();
  runtime.start();
  assert.throws(()=>lease.acquireEntryLease('A',runtime),/in use/);
  assert.equal(lease.releaseEntryLease('A',runtime),undefined);
  assert.equal(runtime.stops,0);
  runtime.status.running=false;
  lease.acquireEntryLease('A',runtime);
  assert.throws(()=>lease.acquireEntryLease('B',runtime),/busy/);
  lease.recordEntryLeaseRun('A',runtime);runtime.start();
  assert.equal(lease.ownsEntryLease('A',runtime),true);
  lease.releaseEntryLease('B',runtime);
  assert.equal(runtime.stops,0);
  lease.releaseEntryLease('A',runtime);
  assert.equal(runtime.stops,1);
  assert.equal(lease.ownsEntryLease('A',runtime),false);
});
test('late cleanup cannot stop a newer run and independent hosts do not share ownership', () => {
  const lease = createEntryLease(), runtime = entry();
  lease.acquireEntryLease('A',runtime);lease.recordEntryLeaseRun('A',runtime);runtime.start();
  runtime.start();
  assert.equal(lease.ownsEntryLease('A',runtime),false);
  lease.releaseEntryLease('A',runtime);
  assert.equal(runtime.stops,0);
  const other = createEntryLease(), otherRuntime = entry();
  other.acquireEntryLease('B',otherRuntime);
  lease.acquireEntryLease('A',entry());
});
test('cleanup failure is returned and releases ownership for subsequent commands', () => {
  const lease = createEntryLease(), runtime = entry();
  lease.acquireEntryLease('A',runtime);lease.recordEntryLeaseRun('A',runtime);runtime.start();
  runtime.stop=()=>false;
  assert.match(lease.releaseEntryLease('A',runtime),/entry refused to stop/);
  runtime.status.running=false;
  lease.acquireEntryLease('B',runtime);
});
