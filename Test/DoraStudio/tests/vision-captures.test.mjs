import test from 'node:test';
import assert from 'node:assert/strict';
import {findPrunableCaptures,COMMAND_VISION_MAX_FILES} from '../packages/agent-contracts/dist/vision-captures.js';
test('original capture retention removes only matching old direct children',()=>{
  assert.equal(COMMAND_VISION_MAX_FILES,60);
  const generated=Array.from({length:62},(_,i)=>`.agent/vision/${1000000000+i}-1.png`);
  const userFiles=['.agent/vision/reference.png','.agent/vision/123-user.png','.agent/vision/sub/1000000000-1.png','other/1000000000-1.png'];
  assert.deepEqual(findPrunableCaptures([...generated,...userFiles]),[generated[1],generated[0]]);
  assert.deepEqual(findPrunableCaptures(generated.slice(0,60)),[]);
  assert.deepEqual(findPrunableCaptures(userFiles),[]);
});
