import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {join} from 'node:path';
import vm from 'node:vm';
const root = process.env.DORA_SSR_ROOT;
if (!root) throw new Error('Set DORA_SSR_ROOT to the Dora-SSR checkout.');
const require = createRequire(join(root, 'Tools/dora-dora/package.json'));
const {build} = require('esbuild');
async function load(file, globals, stubs) {
 const bundled = await build({entryPoints:[join(root,file)],bundle:true,write:false,format:'cjs',platform:'node',plugins:[{name:'mock',setup(b){
  b.onResolve({filter:/^(Dora|Agent\/)/},a=>({path:a.path,namespace:'mock'}));
  b.onLoad({filter:/.*/,namespace:'mock'},a=>({contents:stubs[a.path] ?? 'module.exports={};',loader:'js'}));
 }}]});
 const box={module:{exports:{}},exports:{},console,Promise,tostring:String,...globals};
 vm.runInNewContext(bundled.outputFiles[0].text,box);
 return box.module.exports;
}
let reply={success:true,luaCode:'return 1'}, saves=[], saved=true, listener, connected=1;
let files=['main.ts'];
// Exercise the WebSocket path; native desktop builds delegate to WebServer.
const app={platform:'Linux',runningTime:0};
const path=Object.assign((...p)=>p.join('/'),{getExt:p=>p.split('.').pop(),getName:p=>p.replace(/\.[^.]*$/,''),replaceExt:(p,e)=>p.replace(/\.[^.]*$/,'.'+e)});
const content={load:()=> 'export const n=1;',save:(p,s)=>{saves.push([p,s]);return saved},exist:()=>true,isdir:p=>p.endsWith('/dir'),isAbsolutePath:p=>p.startsWith('/')};
const dora={App:app,Content:content,Path:path,HttpServer:{get wsConnectionCount(){return connected}},Node:()=>({gslot:(_,cb)=>{listener=cb},removeFromParent(){}}),once:fn=>fn,Director:{systemScheduler:{schedule:fn=>fn()}},wait:fn=>{for(let i=0;i<40&&!fn();i++)app.runningTime++},emit:(_,__,text)=>{const r=JSON.parse(text);listener({type:'Receive',msg:JSON.stringify(r.name==='TranspileTSProbe'?{...r,success:true}:{...r,...reply})})}};
let enclosingGodot, enclosingGodotResult={success:true,file:'/project/project.godot'};
const tools=await load('Assets/Script/Lib/Agent/Tool/Build.ts',{__dora:dora,__files:()=>files,__getGodotRoot:()=>enclosingGodot,__buildGodot:async()=>enclosingGodotResult},{Dora:'module.exports=__dora;', 'Agent/Utils':'module.exports={Log(){},safeJsonEncode:o=>[JSON.stringify(o)],safeJsonDecode:s=>[JSON.parse(s)]};','Agent/Tool/GodotBuild':'module.exports={findGodotProject:__getGodotRoot,buildGodotProject:__buildGodot};','Agent/Tool/WebIDESync':'module.exports={sendWebIDEFileUpdate:()=>true};','Agent/Tool/Workspace':'module.exports={resolveWorkspaceSearchPath:(w,p)=>w+"/"+p,toWorkspaceRelativePath:(w,p)=>p,listFiles:()=>({success:true,files:__files()}),codeExtensions:[".ts"]};'});
const buildFile=()=>tools.build({workDir:'/project',path:'main.ts'});
let r=await buildFile();assert.equal(r.success,true);assert.equal(r.passed,1);assert.equal(saves.length,1);
for (const luaCode of [undefined,'','   ']) {reply={success:true,luaCode};saves=[];r=await buildFile();assert.equal(r.success,false);assert.match(r.messages[0].message,/no Lua/);assert.equal(saves.length,0);}
reply={success:false,message:'error TS2322: wrong type'};r=await buildFile();assert.equal(r.success,false);assert.match(r.messages[0].message,/TS2322/);
reply={success:false,failureKind:'tool',message:'compiler service exception'};r=await buildFile();assert.equal(r.failureKind,'tool');assert.equal(r.message,'compiler service exception');
reply={success:true,luaCode:'return 1'};saved=false;r=await buildFile();assert.equal(r.success,false);assert.match(r.messages[0].message,/failed to save/);saved=true;
r=await tools.build({workDir:'/project',path:'types.d.ts'});assert.equal(r.success,false);assert.equal(r.total,0);
files=[];r=await tools.build({workDir:'/project',path:'dir'});assert.equal(r.success,false);
connected=0;r=await buildFile();assert.equal(r.success,false);assert.equal(r.failureKind,'tool');
assert.match(r.message,/not connected/);
const {projectBuildResultForModel,projectMessagesForLLMContext}=await load('Assets/Script/Lib/Agent/Runtime/HistoryProjection.ts',{math:Math},{'Agent/Utils':'module.exports={safeJsonEncode:o=>[JSON.stringify(o)],safeJsonDecode:s=>[JSON.parse(s)]};','Agent/Config/Defaults':'module.exports={AGENT_LIMITS:{llmHistoryBuildMaxMessages:20,llmHistoryToolResultMaxChars:20000}};'});
assert.deepEqual(JSON.parse(JSON.stringify(projectBuildResultForModel(r))),{message:'Build tool call failed: Web IDE not connected'});
const diagnostic={success:false,results:[{success:false,messages:[{success:false,file:'main.ts',message:'TS2322'}]}]};
assert.deepEqual(JSON.parse(JSON.stringify(projectBuildResultForModel(diagnostic))),diagnostic);
assert.equal(projectBuildResultForModel(diagnostic),diagnostic);
assert.deepEqual(JSON.parse(JSON.stringify(projectBuildResultForModel({success:false,code:'TOOL_EXECUTION_FAILED',message:'bridge crashed'}))),{message:'Build tool call failed: bridge crashed'});
const actualContext=projectMessagesForLLMContext([{role:'tool',name:'build',content:JSON.stringify(r)}]);
assert.deepEqual(JSON.parse(actualContext[0].content),{message:'Build tool call failed: Web IDE not connected'});
assert.equal(r.success,false);assert.equal(r.failureKind,'tool');
const legacyContext=projectMessagesForLLMContext([{role:'tool',name:'build',content:JSON.stringify({success:false,code:'TOOL_EXECUTION_FAILED',message:'old bridge error'})}]);
assert.deepEqual(JSON.parse(legacyContext[0].content),{message:'Build tool call failed: old bridge error'});
const {executeAgentToolDefinition}=await load('Assets/Script/Lib/Agent/Tool/Executor.ts',{}, {'Agent/Tool/JsonSchema':'module.exports={compileJsonSchema:()=>({success:true,validator:{validate:()=>({valid:true})}})};','Agent/Tool/Guards':'module.exports={runAgentToolGuards:()=>undefined};'});
const context={cancellation:{isCancelled:()=>false,reason:()=>undefined}};
const definition={name:'build',inputSchema:()=>({}),outputSchema:{},handler:async()=>({output:{success:false,message:'compiler diagnostic'}})};
let executed=await executeAgentToolDefinition(definition,{},context,{});
assert.equal(executed.execution.status,'DONE');assert.equal(executed.output.success,false);
definition.handler=async()=>{throw new Error('bridge exception')};
executed=await executeAgentToolDefinition(definition,{},context,{});
assert.equal(executed.execution.status,'FAILED');assert.equal(executed.output.code,'TOOL_EXECUTION_FAILED');
assert.deepEqual(JSON.parse(JSON.stringify(projectBuildResultForModel(executed.output,executed.execution))),{message:'Build tool call failed: Error: bridge exception'});
context.cancellation.isCancelled=()=>true;
executed=await executeAgentToolDefinition(definition,{},context,{});
assert.equal(executed.execution.status,'STOPPED');
let cancelled=false;
context.cancellation.isCancelled=()=>cancelled;
context.cancellation.reason=()=> 'controlled cancellation';
definition.handler=async()=>{cancelled=true;throw new Error('build interrupted')};
executed=await executeAgentToolDefinition(definition,{},context,{});
assert.equal(executed.execution.status,'STOPPED');
assert.equal(executed.output.code,'TOOL_CANCELLED');
assert.equal(executed.output.message,'controlled cancellation');
console.log('PASS: real build implementation: Lua success/missing/empty, diagnostics, save failure, declarations, empty directory, disconnected service; model result projection.');

// Exercise the real Godot build orchestration with a deterministic Process host.
const nodePath = await import('node:path');
const godotApp = { platform: 'macOS', runningTime: 0 };
const godotPath = Object.assign((...parts)=>nodePath.posix.join(...parts), {
 getPath: nodePath.posix.dirname,
});
const savedScripts = [];
const godotContent = {load:()=> 'config_version=5',glob:()=>[],isdir:p=>!nodePath.posix.extname(p),exist:p=>p==='/project/project.godot',save:(...args)=>{savedScripts.push(args);return true}};
let scenario = 'success', spawned = [], stopped = [], destroyed = [];
const processHost = {
 spawn: spec=>{spawned.push(spec);return scenario==='missing' ? undefined : spawned.length},
 write(){},
 read(handle){
  const spec=spawned[handle-1];
  const version=spec.args[0]==='--version';
  const output=version ? (scenario==='version'?'4.4.1.stable.official':'4.7.2.stable.official')
   : scenario==='diagnostic'?'SCRIPT ERROR: Parse Error at res://unused.gd:2'
   : scenario==='overflow'?'x'.repeat(40000):'';
  return {stdout:output,stderr:'',stdoutOffset:output.length,stderrOffset:0,running:scenario==='timeout',exit:{exitCode:scenario==='exit'?1:0}};
 },
 stop:(...args)=>stopped.push(args),destroy:handle=>destroyed.push(handle),
};
let deferBuild=false,pendingBuild;
const godot = await load('Assets/Script/Lib/Agent/Tool/GodotBuild.ts',{
 __godot:{App:godotApp,Content:godotContent,Path:godotPath,Process:processHost,once:fn=>fn,sleep:()=>{godotApp.runningTime+=61},Director:{systemScheduler:{schedule:fn=>{if(deferBuild)pendingBuild=fn;else fn()}}}},
 os:{getenv:()=>'/configured/Godot'},string:{match:text=>[text.match(/config_version\s*=\s*(\d+)/)?.[1]]},
},{Dora:'module.exports=__godot;','Agent/Tool/Workspace':'module.exports={ensureDirPath:()=>true};','Agent/Tool/WebIDESync':'module.exports={sendWebIDERefreshTree:()=>true};'});
assert.equal(godot.findGodotProject('/project','/project/scenes/main.gd'),'/project');
assert.equal(godot.findGodotProject('/project','/project-other/main.gd'),undefined);
assert.equal(godot.GODOT_EDITOR_VERSION,JSON.parse(require('node:fs').readFileSync(join(root,'Source/3rdParty/Godot/UPSTREAM.json'))).version.replace('-stable',''));
for (const mode of ['success','missing','version','diagnostic','exit','timeout','overflow','cancel']) {
 scenario=mode;spawned=[];stopped=[];destroyed=[];godotApp.runningTime=0;
 const result=await godot.buildGodotProject('/project',()=>mode==='cancel');
 assert.equal(result.success,mode==='success',JSON.stringify(result));
 if (mode==='success') {
  assert.equal(spawned.length,3);
  assert.deepEqual(Array.from(spawned[1].args),['--headless','--quiet','--path','/project','--editor','--import']);
  assert.equal(spawned[2].args.at(-1),'/project/.agent/godot/validate.gd');
  assert.ok(savedScripts.some(([file,content])=>file.endsWith('validate.gd') && content.includes('ResourceLoader.load')));
 }
 if (mode==='diagnostic') assert.match(result.message,/unused.gd:2/);
 if (['missing','version','timeout','overflow','cancel'].includes(mode)) assert.equal(result.failureKind,'tool');
 if (mode==='cancel') assert.equal(result.interrupted,true);
 assert.equal(destroyed.length,mode==='missing'?0:spawned.length);
 assert.equal(stopped.length,destroyed.length);
}
spawned=[];godotApp.platform='Android';
assert.equal((await godot.buildGodotProject('/project')).failureKind,'tool');
assert.equal(spawned.length,0);
console.log('PASS: Godot editor import/resource validation, version guard, diagnostic errors at exit zero, cancellation, timeout, output cap, process cleanup, desktop capability guard.');

godotApp.platform='macOS';spawned=[];
godotContent.load=()=> 'config_version=4';
assert.equal((await godot.buildGodotProject('/project')).success,false);
assert.equal(spawned.length,0);
godotContent.load=()=> 'config_version=5\nconfig/features=PackedStringArray("C#")';
assert.equal((await godot.buildGodotProject('/project')).success,false);
assert.equal(spawned.length,0);
console.log('PASS: Godot 3 conversion and unsupported Mono rejected before launching editor.');

scenario='success';godotContent.load=()=> 'config_version=5';deferBuild=true;
const firstBuild=godot.buildGodotProject('/project');
assert.match((await godot.buildGodotProject('/project')).message,/already running/);
deferBuild=false;pendingBuild();
assert.equal((await firstBuild).success,true);
assert.equal((await godot.buildGodotProject('/project')).success,true);
console.log('PASS: concurrent import rejected and project lock released after completion.');

connected=1;reply={success:true,luaCode:'return 1'};enclosingGodot='/project';
saves=[];r=await buildFile();assert.equal(r.success,true);assert.equal(r.passed,2);
enclosingGodotResult={success:false,file:'/project/project.godot',message:'res://main.gd:2: Parse Error'};
saves=[];r=await buildFile();assert.equal(r.success,false);assert.equal(saves.length,0);
assert.match(r.messages[0].message,/main.gd:2/);
enclosingGodotResult={success:false,file:'/project/project.godot',failureKind:'tool',message:'editor unavailable'};
r=await buildFile();assert.equal(r.failureKind,'tool');
console.log('PASS: building a Dora wrapper validates its Godot project first and cannot mask Godot failures.');
