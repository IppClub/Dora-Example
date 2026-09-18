import test from 'node:test';
import assert from 'node:assert/strict';
import {build} from 'esbuild';
const bundle = await build({entryPoints:['apps/web/src/agent-session-state.ts'], bundle:true, write:false, format:'esm', platform:'node'});
const {createAgentSessionState, applyAgentSessionPatch, replaceAgentSessionSnapshot} = await import('data:text/javascript;base64,' + Buffer.from(bundle.outputFiles[0].text).toString('base64'));
const snapshot = () => ({session:{id:1, metrics:{usage:{totalTokens:10}}}, messages:[], steps:[], checkpoints:[], relatedSessions:[], pendingQuestionnaire:{id:1}, spawnInfo:null, hasActivePlan:true, pendingMergeCount:2, pendingMergeJobs:[{jobId:'a'}]});
const patch = fields => ({name:'AgentSessionPatch', sessionId:1, ...fields});

test('partial metrics and unrelated events preserve existing session state', () => {
  const original = createAgentSessionState(snapshot());
  const next = applyAgentSessionPatch(original, patch({metrics:{context:{usedTokens:5}}}));
  assert.equal(next.session.metrics.usage.totalTokens, 10);
  assert.equal(next.session.metrics.context.usedTokens, 5);
  assert.equal(next.pendingQuestionnaire.id, 1);
  assert.equal(next.messages, original.messages);
  assert.equal(original.session.metrics.context, undefined);
});
test('explicit empty values clear questions, plans and merge state without truthiness bugs', () => {
  const next = applyAgentSessionPatch(createAgentSessionState(snapshot()), patch({pendingQuestionnaire:false, hasActivePlan:false, pendingMergeCount:0, pendingMergeJobs:[], relatedSessions:[]}));
  assert.equal(next.pendingQuestionnaire, null);
  assert.equal(next.hasActivePlan, false);
  assert.equal(next.pendingMergeCount, 0);
  assert.deepEqual(next.pendingMergeJobs, []);
});
test('foreign events are ignored, nested foreign records rejected, and deletion is terminal', () => {
  const original = createAgentSessionState(snapshot());
  assert.equal(applyAgentSessionPatch(original, {...patch({}), sessionId:2}), original);
  for (const fields of [{session:{id:2}}, {message:{sessionId:2}}, {step:{sessionId:2}}]) assert.throws(() => applyAgentSessionPatch(original, patch(fields)), /Mismatched/);
  const deleted = applyAgentSessionPatch(original, patch({sessionDeleted:true}));
  assert.equal(deleted.deleted, true);
  assert.equal(applyAgentSessionPatch(deleted, patch({session:{id:1}})), deleted);
});
test('snapshot and incoming message mutations cannot change captured state', () => {
  const input = snapshot();
  const initial = createAgentSessionState(input);
  input.session.id = 9;
  assert.equal(initial.session.id, 1);
  const event = patch({message:{id:1, sessionId:1, content:'saved'}});
  const next = applyAgentSessionPatch(initial, event);
  event.message.content = 'changed';
  assert.equal(next.messages.byId.get(1).content, 'saved');
  assert.equal(initial.messages.byId.size, 0);
});

test('limited history remains marked through patches and clears only on a full snapshot', () => {
  const detail = {...snapshot(), hasEarlierMessages:true, messages:[{id:2, sessionId:1, content:'recent'}]};
  const initial = createAgentSessionState(detail);
  const patched = applyAgentSessionPatch(initial, patch({metrics:{context:{usedTokens:3}}}));
  assert.equal(patched.hasEarlierMessages, true);
  const refreshed = replaceAgentSessionSnapshot(patched, {...detail, hasEarlierMessages:false, messages:[{id:1, sessionId:1, content:'older'}, ...detail.messages]});
  assert.equal(refreshed.hasEarlierMessages, false);
  assert.deepEqual(refreshed.messages.orderedIds, [1,2]);
  assert.equal(refreshed.messages.byId.get(2), initial.messages.byId.get(2));
  assert.deepEqual(initial.messages.orderedIds, [2]);
});

test('snapshot replacement rejects another session and cannot revive a deleted one', () => {
  const initial = createAgentSessionState(snapshot());
  assert.throws(() => replaceAgentSessionSnapshot(initial, {...snapshot(),session:{id:2}}), /Mismatched/);
  const deleted = applyAgentSessionPatch(initial, patch({sessionDeleted:true}));
  assert.equal(replaceAgentSessionSnapshot(deleted, snapshot()), deleted);
  const {pendingMergeCount,pendingMergeJobs,...nativeDetail} = snapshot();
  const native = createAgentSessionState(nativeDetail);
  assert.equal(native.pendingMergeCount, 0);
  assert.deepEqual(native.pendingMergeJobs, []);
});
