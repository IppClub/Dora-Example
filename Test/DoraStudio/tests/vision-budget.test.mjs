import test from 'node:test';
import assert from 'node:assert/strict';
import {createVisionBudget} from '../packages/agent-contracts/dist/vision-budget.js';
const row=(tool,result)=>[tool,JSON.stringify(result)];
test('original vision budget restores captures and billed failed analysis without inventing missing usage',()=>{
  const api=createVisionBudget({TABLE_STEP:'steps',DB:{query(sql,args){
    assert.match(sql,/task_id=\?/);assert.deepEqual(args,[7]);
    return [row('execute_command',{success:false,visionCapture:{batchCount:1,frameCount:3}}),
      row('analyze_image',{success:false,requestIssued:true,usage:{prompt_tokens:100,completion_tokens:20}}),
      row('analyze_image',{requestIssued:true}),row('analyze_image',{requestIssued:false,usage:{prompt_tokens:1000,completion_tokens:1000}}),
      ['analyze_image','invalid json']];
  }}});
  const state=api.getVisionBudgetState(api.getVisionTaskUsage(7));
  assert.equal(state.captureBatchCount,1);assert.equal(state.captureFrameCount,3);
  assert.equal(state.requestCount,2);assert.equal(state.reportedRequests,1);assert.equal(state.totalTokens,120);
  assert.deepEqual(state.limits,{captureBatches:3,captureFrames:6,analysisRequests:3,reportedTokens:60000});
  assert.deepEqual(state.remaining,{captureBatches:2,captureFrames:3,analysisRequests:1,reportedTokens:59880});
});
test('original vision budget handles invalid counts, exhausted budgets and unavailable history',()=>{
  const api=createVisionBudget({TABLE_STEP:'steps',DB:{query(){return [row('execute_command',{visionCapture:{batchCount:9.8,frameCount:-1}})];}}});
  const state=api.getVisionBudgetState(api.getVisionTaskUsage(1));
  assert.equal(state.captureBatchCount,9);assert.equal(state.captureFrameCount,0);assert.equal(state.remaining.captureBatches,0);
  const unavailable=createVisionBudget({TABLE_STEP:'steps',DB:{query(){return undefined;}}});
  assert.throws(()=>unavailable.getVisionTaskUsage(1),/Unable to read/);
  assert.equal(unavailable.getVisionTaskUsage(0).requestCount,0);
});
