import test from 'node:test';
import assert from 'node:assert/strict';
import {isRuntimeCommand,isRuntimeEvent,matchesCaptureResult,MAX_CAPTURE_BYTES} from '../packages/contracts/dist/index.js';
const identity={version:1,sessionId:'s',projectId:'p',revision:1,requestId:'r',runId:'run'};
const command={...identity,type:'captureGame',captureId:'capture-1'};
function event() {
  const png = new Uint8Array(33);
  png.set([137,80,78,71,13,10,26,10,0,0,0,13,73,72,68,82]);
  const header=new DataView(png.buffer);header.setUint32(16,300);header.setUint32(20,150);
  return {...identity,type:'gameCaptured',captureId:'capture-1',png,width:300,height:150};
}
test('capture protocol binds results to both run identity and capture request',()=>{
  assert.equal(isRuntimeCommand(command),true);
  assert.equal(isRuntimeEvent(event()),true);
  assert.equal(matchesCaptureResult(command,event()),true);
  for(const field of ['sessionId','projectId','requestId','runId','captureId'])
    assert.equal(matchesCaptureResult(command,{...event(),[field]:'other'}),false);
  assert.equal(matchesCaptureResult(command,{...event(),revision:2}),false);
  for(const captureId of ['', '../file', 'x'.repeat(129)]) assert.equal(isRuntimeCommand({...command,captureId}),false);
});
test('capture envelope rejects oversized images, mismatched IHDR and malformed failures',()=>{
  for(const patch of [{width:301},{height:0},{width:1281},{png:new Uint8Array(MAX_CAPTURE_BYTES+1)},
    {png:new Uint8Array(33)},{png:[]},{width:NaN}]) assert.equal(isRuntimeEvent({...event(),...patch}),false);
  const failure={...identity,type:'captureFailed',captureId:'capture-1',message:'capture unavailable'};
  assert.equal(isRuntimeEvent(failure),true);
  assert.equal(matchesCaptureResult(command,failure),true);
  assert.equal(isRuntimeEvent({...failure,message:'x'.repeat(8193)}),false);
});
