import test from 'node:test';
import assert from 'node:assert/strict';
import {build} from 'esbuild';

const bundled=await build({entryPoints:['apps/web/src/agent-tool-build.ts'],bundle:true,write:false,format:'esm',platform:'node',plugins:[{name:'compiler-fixture',setup(builder){
  builder.onResolve({filter:/^@dora-studio\/compiler-web$/},()=>({path:'compiler',namespace:'fixture'}));
  builder.onLoad({filter:/.*/,namespace:'fixture'},()=>({loader:'js',contents:'export const createBrowserCompiler=()=>({compile:async()=>globalThis.__agentBuildReply,dispose(){}});'}));
}}]});
const {transpileAgentTsTool}=await import('data:text/javascript;base64,'+Buffer.from(bundled.outputFiles[0].text).toString('base64'));
const root='/user/studio-project',encoder=new TextEncoder(),source='export function normalize(value: number) {\n  if (value) return 1;\n  return 0;\n}';

function fixtureFS(){
  const files=new Map([[root+'/main.ts',encoder.encode(source)]]),dirs=new Set([root]);
  return {analyzePath:path=>({exists:files.has(path)||dirs.has(path)}),lstat:path=>dirs.has(path)?{mode:16384,size:0}:{mode:32768,size:files.get(path).byteLength},
    isDir:mode=>mode===16384,isFile:mode=>mode===32768,readdir:path=>path===root?['.','..','main.ts']:[],readFile:path=>new Uint8Array(files.get(path)),
    writeFile(){},mkdirTree(){},rename(){},unlink(){},rmdir(){}};
}
const request={operation:'transpile-ts',file:root+'/main.ts',projectRoot:root,content:source};
const originalFetch=globalThis.fetch;
const originalLocation=globalThis.location;
globalThis.fetch=async()=>({ok:true,text:async()=>''});
globalThis.location={href:'http://studio.test/'};

test.after(()=>{
  globalThis.fetch=originalFetch;
  if(originalLocation===undefined)delete globalThis.location;else globalThis.location=originalLocation;
  delete globalThis.__agentBuildReply;
});

test('original Agent adapter reports compiler warnings as build problems',async()=>{
  globalThis.__agentBuildReply={type:'compiled',diagnostics:[{severity:'warning',code:'100037',path:'main.ts',start:source.indexOf('value)'),message:'Lua truthiness differs'}],artifact:{files:[{path:'main.lua',kind:'text',text:'return 1'}]}};
  const result=await transpileAgentTsTool(fixtureFS(),'p',request,new AbortController().signal);
  assert.equal(result.success,false);assert.equal(result.message,'Compiling error: /user/studio-project/main.ts\nmain.ts(2,7): warning TS100037: Lua truthiness differs\n');
});

test('original Agent adapter still returns generated Lua for a clean build',async()=>{
  globalThis.__agentBuildReply={type:'compiled',diagnostics:[],artifact:{files:[{path:'main.lua',kind:'text',text:'return 1'}]}};
  assert.deepEqual(await transpileAgentTsTool(fixtureFS(),'p',request,new AbortController().signal),{success:true,luaCode:'return 1'});
});
