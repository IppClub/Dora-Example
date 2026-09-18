import test from 'node:test';
import assert from 'node:assert/strict';
import {build} from 'esbuild';
const result=await build({entryPoints:['apps/web/src/runtime-image.ts'],bundle:true,write:false,platform:'browser',format:'esm'});
const {decodeGameCapture}=await import(`data:text/javascript;base64,${Buffer.from(result.outputFiles[0].text).toString('base64')}`);
function header() {
  const png=new Uint8Array(33);png.set([137,80,78,71,13,10,26,10,0,0,0,13,73,72,68,82]);
  const view=new DataView(png.buffer);view.setUint32(16,1);view.setUint32(20,1);return png;
}
test('trusted capture decoding rejects malformed payloads and closes bitmap resources',async()=>{
  let closed=0;
  await assert.rejects(decodeGameCapture(new Uint8Array(0),1,1,()=>assert.fail('must reject before decode')));
  await assert.rejects(decodeGameCapture(header(),1,1,async()=>{throw new Error('broken PNG');}),/broken PNG/);
  await assert.rejects(decodeGameCapture(header(),1,1,async()=>({width:2,height:1,close(){closed++;}})),/不一致/);
  assert.equal(closed,1);
  const source=header();
  const decoded=await decodeGameCapture(source,1,1,async blob=>{
    assert.equal(blob.type,'image/png');source.fill(0);return {width:1,height:1,close(){closed++;}};
  });
  assert.equal(decoded[0],137);assert.equal(closed,2);
});
