import test from 'node:test';
import assert from 'node:assert/strict';
import {build} from 'esbuild';

const bundle=await build({entryPoints:['apps/web/src/agent-tool-script-build.ts'],bundle:true,write:false,format:'esm',platform:'node'});
const {buildAgentScriptTool}=await import('data:text/javascript;base64,'+Buffer.from(bundle.outputFiles[0].text).toString('base64'));
const root='/user/studio-project',encoder=new TextEncoder();
function fixtureFS(path,content){
  const files=new Map([[root+'/'+path,encoder.encode(content)]]);
  return {files,analyzePath:name=>({exists:files.has(name)||name===root}),
    lstat:name=>name===root?{mode:16384,size:0}:files.has(name)?{mode:32768,size:files.get(name).byteLength}:(()=>{throw Error('not found')})(),
    isDir:mode=>mode===16384,isFile:mode=>mode===32768,
    readdir:name=>name===root?['.','..',path]:[],readFile:name=>new Uint8Array(files.get(name)),
    writeFile:()=>{throw Error('Tool host must not write generated code')},mkdirTree:()=>{},rename:()=>{},unlink:()=>{},rmdir:()=>{},
  };
}
const request=(path,content)=>({operation:'build-script',file:root+'/'+path,content,projectRoot:root});

test('original Agent Teal build request compiles the exact installed source and returns Dora header',async()=>{
  const content='local n: number = 1\nprint(n)',fs=fixtureFS('main.tl',content);let called=0;
  const reply=await buildAgentScriptTool(fs,'owned',request('main.tl',content),new AbortController().signal,
    async(snapshot,path)=>{called++;assert.equal(path,'main.tl');assert.equal(snapshot.projectId,'owned');assert.equal(snapshot.files[0].text,content);return {success:true,code:'print(1)',tic80:false};});
  assert.deepEqual(reply,{success:true,luaCode:'-- [tl]: main.tl\nprint(1)'});assert.equal(called,1);assert.equal(fs.files.size,1);
});

test('original Agent Lua build validates source without overwriting it',async()=>{
  const content='print("ready")',fs=fixtureFS('init.lua',content);
  const reply=await buildAgentScriptTool(fs,'owned',request('init.lua',content),new AbortController().signal,
    async(_snapshot,path)=>{assert.equal(path,'init.lua');return {success:true};});
  assert.deepEqual(reply,{success:true,luaCode:''});assert.equal(fs.files.size,1);
});

test('original Agent Yarn build validates a dialogue file without generating Lua',async()=>{
  const content='title: Start\n---\nHello\n===\n',fs=fixtureFS('dialog.yarn',content);
  const reply=await buildAgentScriptTool(fs,'owned',request('dialog.yarn',content),new AbortController().signal,
    async(_snapshot,path)=>{assert.equal(path,'dialog.yarn');return {success:true};});
  assert.deepEqual(reply,{success:true,luaCode:''});assert.equal(fs.files.size,1);
});

test('TIC80 Teal output preserves the original leading marker before the Dora source header',async()=>{
  const content='-- tic80\nprint("ready")',fs=fixtureFS('main.tl',content);
  const reply=await buildAgentScriptTool(fs,'owned',request('main.tl',content),new AbortController().signal,
    async()=>({success:true,code:'-- tic80\nprint("ready")',tic80:true}));
  assert.deepEqual(reply,{success:true,luaCode:'-- tic80\n-- [tl]: main.tl\nprint("ready")'});
});

test('script build rejects changed input, unsupported target and cancellation before claiming success',async()=>{
  const content='print("ready")',fs=fixtureFS('init.lua',content);let calls=0;
  const compile=async()=>{calls++;return {success:true,code:'ok'};};
  assert.equal((await buildAgentScriptTool(fs,'owned',request('init.lua','changed'),new AbortController().signal,compile)).success,false);
  assert.equal((await buildAgentScriptTool(fs,'owned',request('../secret.lua',content),new AbortController().signal,compile)).success,false);
  assert.equal((await buildAgentScriptTool(fs,'owned',request('init.yue',content),new AbortController().signal,compile)).success,false);
  assert.equal(calls,0);
  const abort=new AbortController();
  const pending=buildAgentScriptTool(fs,'owned',request('init.lua',content),abort.signal,async()=>{abort.abort();return {success:true};});
  await assert.rejects(pending);
});
