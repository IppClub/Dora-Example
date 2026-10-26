// Verify collection ordering without launching a browser or an engine instance.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import test from 'node:test';

test('OGV harness waits for this run and publishes only after all screenshots', async()=>{
 const html=fs.readFileSync(new URL('../Video/web_ogv_harness.html',import.meta.url),'utf8');
 const source=html.match(/<script>([\s\S]*?)<\/script>/)[1];
 const elements=new Map();
 const element=key=>{if(!elements.has(key))elements.set(key,{textContent:'',disabled:false});return elements.get(key);};
 const files=new Map([['/user/ogv-controls/result.json',JSON.stringify({success:true,captures:[{file:'old.png'}]})]]);
 const requests=[];let interval,failCapture=true;
 const context={URLSearchParams,Uint8Array,location:{search:'?case=controls'},
  document:{querySelector:element},setInterval:callback=>{interval=callback;},
  navigator:{userAgent:'test'},crossOriginIsolated:false,
  btoa:value=>Buffer.from(value,'binary').toString('base64'),
  fetch:async(url,options)=>{requests.push({url,body:JSON.parse(options.body)});return {ok:!('file' in requests.at(-1).body)||!failCapture};}};
 vm.runInNewContext(source,context);
 context.Module.FS={
  readFile:path=>{if(!files.has(path))throw Error('missing');return files.get(path);},
  unlink:path=>files.delete(path),writeFile:(path,bytes)=>files.set(path,bytes)};
 context.Module.doraAudio={ready:true,context:{resume:async()=>{}},state:{ready:true}};
 await interval();assert.equal(element('#unlock').disabled,true,'FS readiness alone must not start the test');
 context.Module.print('OGV_TEST_READY');await interval();
 assert.equal(element('#unlock').disabled,false);
 assert.equal(requests.length,0,'saved results must not be collected before Start');
 await element('#unlock').onclick();
 assert.ok(!files.has('/user/ogv-controls/result.json'),'discard previous result before starting');
 await interval();assert.equal(requests.length,0);
 files.set('/user/ogv-controls/result.json',JSON.stringify({success:true,captures:[{file:'new.png'}]}));
 files.set('/user/ogv-controls/new.png',new Uint8Array([1,2,3]));
 await interval();assert.equal(requests.length,1);assert.equal(requests[0].body.file,'new.png');
 assert.equal(element('#result').textContent,'Running controls…','an incomplete upload must not report success');
 failCapture=false;await interval();
 assert.equal(requests.length,3);assert.equal(requests[1].body.file,'new.png');
 assert.equal(requests[2].body.result.success,true);
 await interval();assert.equal(requests.length,3,'a completed run must not upload twice');
});
