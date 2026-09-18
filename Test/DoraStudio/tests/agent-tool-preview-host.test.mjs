import test from 'node:test';
import assert from 'node:assert/strict';
import {build} from 'esbuild';

const bundle=await build({entryPoints:['apps/web/src/agent-tool-preview-host.ts'],bundle:true,write:false,format:'esm',platform:'node'});
const {previewAgentGameTool}=await import('data:text/javascript;base64,'+Buffer.from(bundle.outputFiles[0].text).toString('base64'));
const encoder=new TextEncoder();
const root='/user/studio-project';
const input={operation:'preview-game',file:root+'/main.lua',projectRoot:root,content:'{"entry":"main.ts","captureAtSeconds":[0.5]}'};

function fixtureFS(){
  const files=new Map([[root+'/main.lua',encoder.encode('print("READY")')]]),dirs=new Set([root]);
  return {files,dirs,
    analyzePath:path=>({exists:files.has(path)||dirs.has(path)}),
    lstat:path=>dirs.has(path)?{mode:16384,size:0}:files.has(path)?{mode:32768,size:files.get(path).byteLength}:(()=>{throw Error('not found')})(),
    isDir:mode=>mode===16384,isFile:mode=>mode===32768,
    readdir:path=>path===root?['.','..','main.lua','.agent']:[],
    readFile:path=>new Uint8Array(files.get(path)),
    writeFile:(path,bytes)=>files.set(path,new Uint8Array(bytes)),
    mkdirTree:path=>dirs.add(path),rename:()=>{},unlink:path=>files.delete(path),rmdir:path=>dirs.delete(path),
  };
}

test('original preview tool packages built Lua and stores isolated Player PNG only under private vision',async()=>{
  const fs=fixtureFS();let artifact;
  const broker=async(value,times)=>{
    artifact=value;assert.deepEqual(times,[0.5]);
    return [{png:Uint8Array.from([137,80,78,71,13,10,26,10,1]),width:100,height:50,elapsedSeconds:0.55}];
  };
  const reply=await previewAgentGameTool(fs,'owned',7,input,broker,new AbortController().signal);
  assert.equal(reply.success,true);
  assert.equal(artifact.projectId,'owned');assert.equal(artifact.revision,7);assert.equal(artifact.entry,'main.lua');
  assert.equal(artifact.files.length,1);assert.equal(artifact.files[0].text,'print("READY")');
  assert.match(artifact.sha256,/^[0-9a-f]{64}$/);
  const result=JSON.parse(reply.resultJSON);
  assert.equal(result.success,true);assert.equal(result.frames.length,1);
  assert.match(result.files[0],/^\.agent\/vision\/\d+-\d+\.png$/);
  assert.deepEqual([...fs.files.get(root+'/'+result.files[0])],[137,80,78,71,13,10,26,10,1]);
});

test('preview tool rejects unbuilt or rebound entry before starting a Player',async()=>{
  const fs=fixtureFS();let called=false;
  const broker=async()=>{called=true;return [];};
  assert.equal((await previewAgentGameTool(fs,'owned',0,{...input,file:root+'/other.lua'},broker,new AbortController().signal)).success,false);
  assert.equal((await previewAgentGameTool(fs,'owned',0,{...input,content:'{"entry":"../secret.ts","captureAtSeconds":[0.5]}'},broker,new AbortController().signal)).success,false);
  assert.equal(called,false);
});

test('preview tool abort does not leave a private screenshot',async()=>{
  const fs=fixtureFS(),abort=new AbortController();
  await assert.rejects(previewAgentGameTool(fs,'owned',0,input,async()=>{abort.abort();return [{png:Uint8Array.from([137,80,78,71,13,10,26,10]),width:1,height:1,elapsedSeconds:1}];},abort.signal));
  assert.equal([...fs.files.keys()].some(path=>path.includes('/.agent/vision/')),false);
});
