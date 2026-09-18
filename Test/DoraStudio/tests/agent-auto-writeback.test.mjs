import test from 'node:test';
import assert from 'node:assert/strict';
import {build} from 'esbuild';

const bundle=await build({entryPoints:['apps/web/src/agent-auto-writeback.ts'],bundle:true,write:false,format:'esm',platform:'node'});
const {initialPromptTerminal,shouldAutoWriteback}=await import('data:text/javascript;base64,'+Buffer.from(bundle.outputFiles[0].text).toString('base64'));
test('automatic writeback waits for the exact original main task terminal state',()=>{
  const session={kind:'main',currentTaskId:19,status:'RUNNING',currentTaskStatus:'RUNNING'};
  assert.equal(initialPromptTerminal(session,19),undefined);
  session.status='DONE';session.currentTaskStatus='DONE';assert.equal(initialPromptTerminal(session,19),'DONE');
  assert.equal(initialPromptTerminal(session,20),undefined);
  assert.equal(initialPromptTerminal({...session,kind:'sub'},19),undefined);
  assert.equal(initialPromptTerminal({...session,currentTaskStatus:'RUNNING'},19),undefined);
  assert.equal(initialPromptTerminal({...session,status:'FAILED',currentTaskStatus:'FAILED'},19),'FAILED');
  assert.equal(initialPromptTerminal({...session,status:'STOPPED',currentTaskStatus:'STOPPED'},19),'STOPPED');
});

test('every terminal Agent task is eligible for automatic writeback',()=>{
  assert.equal(shouldAutoWriteback('DONE'),true);
  assert.equal(shouldAutoWriteback('FAILED'),true);
  assert.equal(shouldAutoWriteback('STOPPED'),true);
  assert.equal(shouldAutoWriteback(undefined),false);
});
