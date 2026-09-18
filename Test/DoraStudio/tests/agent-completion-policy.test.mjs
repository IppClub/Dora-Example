import test from 'node:test';
import assert from 'node:assert/strict';
import {build} from 'esbuild';

const built=await build({entryPoints:['../Assets/Script/Lib/Agent/Runtime/CompletionPolicy.ts'],bundle:true,write:false,format:'esm',platform:'node'});
const {getAuthoredCompletionBlocker}=await import(`data:text/javascript;base64,${Buffer.from(built.outputFiles[0].text).toString('base64')}`);

test('main Agent completion is blocked until authored changes build successfully',()=>{
  assert.match(getAuthoredCompletionBlocker({unbuiltEdits:true}),/still unbuilt/);
  assert.match(getAuthoredCompletionBlocker({hasBuilt:true,lastBuildSucceeded:false}),/latest project build failed/);
  assert.match(getAuthoredCompletionBlocker({buildRepairPending:true}),/latest project build failed/);
  assert.equal(getAuthoredCompletionBlocker({hasBuilt:true,lastBuildSucceeded:true,unbuiltEdits:false}),undefined);
  assert.equal(getAuthoredCompletionBlocker({}),undefined);
});
