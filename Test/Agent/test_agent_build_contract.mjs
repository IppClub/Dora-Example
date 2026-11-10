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
const tools=await load('Assets/Script/Lib/Agent/Tool/Build.ts',{__dora:dora,__files:()=>files,__getGodotRoot:()=>enclosingGodot,__buildGodot:async()=>enclosingGodotResult},{Dora:'module.exports=__dora;', 'Agent/Utils':'module.exports={Log(){},safeJsonEncode:o=>[JSON.stringify(o)],safeJsonDecode:s=>[JSON.parse(s)]};','Agent/Tool/GodotBuild':'module.exports={findGodotProject:__getGodotRoot,buildGodotProject:__buildGodot};','Agent/Tool/WebIDESync':'module.exports={sendWebIDEFileUpdate:()=>true};','Agent/Tool/Workspace':'module.exports={resolveWorkspaceSearchPath:(w,p)=>w+"/"+p,toWorkspaceRelativePath:(w,p)=>p.startsWith(w+"/")?p.slice(w.length+1):p,listFiles:()=>({success:true,files:__files()}),codeExtensions:[".ts"]};'});
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

// Native compiler checks: no Process host or external editor is provided.
const nodePath = await import('node:path');
const nativeQueue=[],nativeCalls=[];
let available=true,nativeResult={success:true,info:[]},nativeHook;
const nativeClass={checkCodeAsync:(project,file,content,callback)=>{
 nativeCalls.push({project,file,content});nativeHook?.();
 callback(available,available?JSON.stringify(nativeResult):'bundled compiler API unavailable');
}};
// Dora preserves a single path argument and a trailing slash from joining '.'.
// node:path.join alone hides the native workspace-root regression.
const nativePath=Object.assign((...parts)=>parts.length===1?parts[0]:nodePath.posix.join(...parts)+(parts.at(-1)==='.'?'/':''),{getPath:nodePath.posix.dirname,getRelative:(file,base)=>nodePath.posix.relative(base,file),getFilename:nodePath.posix.basename});
const doraCheck={Content:{load:()=>'config_version=5',glob:()=>[],isAbsolutePath:nodePath.posix.isAbsolute},GodotNode:nativeClass,Path:nativePath,once:fn=>fn,sleep:()=>{},Director:{systemScheduler:{schedule:fn=>nativeQueue.push(fn)}}};
const check=await load('Assets/Script/Lib/Agent/Tool/GodotCheck.ts',{
 __nativeDora:doraCheck,string:{match:text=>[text.match(/config_version\s*=\s*(\d+)/)?.[1]]},type:v=>v===undefined?'nil':typeof v==='object'?'table':typeof v,
},{Dora:'module.exports=__nativeDora;','Agent/Utils':'module.exports={safeJsonDecode:text=>{try{return[JSON.parse(text)]}catch{return[]}}};'});
const drainNative=()=>{while(nativeQueue.length)nativeQueue.shift()();};
for(const extension of ['gd','tscn','tres','gdshader','gdshaderinc']){
 const file='/project/main.'+extension;
 nativeResult={success:false,info:[['syntax',file,3,1,'bad syntax']]};
 let promise=check.checkGodotFile('/project',file,'unsaved code');drainNative();let result=await promise;
 assert.equal(result.success,false);assert.equal(result.info[0][2],3);assert.equal(nativeCalls.at(-1).content,'unsaved code');
 nativeResult={success:true,info:[]};promise=check.checkGodotFile('/project',file,'repaired');drainNative();assert.equal((await promise).success,true);
}
available=false;let promise=check.checkGodotFile('/project','/project/main.gd','');drainNative();let nativeAnswer=await promise;
assert.equal(nativeAnswer.info[0][0],'tool');assert.match(nativeAnswer.info[0][4],/unavailable/);available=true;
const stale=check.checkGodotFile('/project','/project/main.gd','old');const fresh=check.checkGodotFile('/project','/project/main.gd','new');drainNative();
assert.equal((await stale).skipped,true);assert.equal((await fresh).success,true);assert.equal(nativeCalls.at(-1).content,'new');
assert.equal((await check.checkGodotFile('/project','/outside/main.gd','')).success,false);
for(const project of ['/project/',nativePath('/project','.'),'/project/.']){
 const promise=check.checkGodotFile(project,nativePath(project,'project.godot'),'config_version=5');drainNative();
 assert.equal((await promise).success,true,project);
 assert.equal(nativeCalls.at(-1).project,'/project');
}
for(const file of ['/project-other/main.gd','/project/../outside/main.gd','/project']){
 const before=nativeCalls.length;assert.equal((await check.checkGodotFile('/project/',file,'')).success,false);assert.equal(nativeCalls.length,before);
}
const rootCheck=check.checkGodotFile('/','/project.godot','config_version=5');drainNative();assert.equal((await rootCheck).success,true);
const savedNative=nativeClass.checkCodeAsync;delete nativeClass.checkCodeAsync;
assert.equal((await check.checkGodotFile('/project','/project/main.gd','')).success,false);nativeClass.checkCodeAsync=savedNative;
const fs=require('node:fs');
for(const file of ['GodotCheck.ts','GodotBuild.ts'])assert.doesNotMatch(fs.readFileSync(join(root,'Assets/Script/Lib/Agent/Tool',file),'utf8'),/Process[.:]|DORA_GODOT_EDITOR|--headless|--import/);
assert.match(fs.readFileSync(join(root,'Assets/Script/Lib/Agent/Tool/GodotCheck.lua'),'utf8'),/GodotNode:checkCodeAsync\(/);
console.log('PASS: live Godot checks use the bundled compiler bridge with unsaved text, diagnostics, coalescing and capability failures; no subprocess/editor fallback.');

let settings='config_version=5',sidecars=[],buildChecks=[],deferNative=false,finishNative;
const nativeBuildLogs=[];
let compiledResult={success:true,info:[]};
const godot=await load('Assets/Script/Lib/Agent/Tool/GodotBuild.ts',{
 __buildDora:{Path:nativePath,Log:(level,message)=>nativeBuildLogs.push({level,message}),Content:{isdir:path=>path==='/project',exist:path=>path==='/project/project.godot',load:file=>file.endsWith('project.godot')?settings:'source',glob:(_,globs)=>{if(globs[0]==='**/*.gdextension')return sidecars;assert.ok(globs.includes('**/*.gdshader'));assert.ok(globs.includes('**/*.gdshaderinc'));return ['main.gd','main.tscn','effect.gdshader','common.gdshaderinc'];}}},
 string:{match:text=>[text.match(/config_version\s*=\s*(\d+)/)?.[1]]},
 __checkNative:(project,file,content)=>{buildChecks.push(file);return deferNative?new Promise(resolve=>finishNative=resolve):Promise.resolve(compiledResult)},
},{Dora:'module.exports=__buildDora;','Agent/Tool/GodotCheck':'module.exports={checkGodotFile:__checkNative};'});
assert.equal(godot.findGodotProject('/project','/project/scenes/main.gd'),'/project');
assert.equal(godot.findGodotProject('/project','/other/main.gd'),undefined);
assert.equal(godot.findGodotProject('/project/','/project/main.gd'),'/project');
assert.equal(godot.findGodotProject('/project/','/project'),'/project');
assert.equal(godot.GODOT_RUNTIME_VERSION,JSON.parse(fs.readFileSync(join(root,'Source/3rdParty/Godot/UPSTREAM.json'))).version.replace('-stable',''));
const nativeSuccess=await godot.buildGodotProject('/project');assert.equal(nativeSuccess.success,true);assert.deepEqual(buildChecks,['/project/project.godot','/project/main.gd','/project/main.tscn','/project/effect.gdshader','/project/common.gdshaderinc']);
assert.deepEqual(nativeBuildLogs.map(item=>item.message),['Built Godot project/project.godot','Built Godot project/main.gd','Built Godot project/main.tscn','Built Godot project/effect.gdshader','Built Godot project/common.gdshaderinc']);
assert.equal(nativeSuccess.messages.length,5);assert.ok(nativeSuccess.messages.every(item=>item.success&&item.message.includes('Godot validation passed')));
for(const project of ['/project/','/project/.']){
 buildChecks=[];assert.equal((await godot.buildGodotProject(project)).success,true);
 assert.deepEqual(buildChecks,['/project/project.godot','/project/main.gd','/project/main.tscn','/project/effect.gdshader','/project/common.gdshaderinc']);
}
compiledResult={success:false,info:[['syntax','/project/main.gd',2,1,'Parse Error']]};let nativeBuild=await godot.buildGodotProject('/project');assert.match(nativeBuild.message,/res:\/\/main.gd:2:1/);
compiledResult={success:false,info:[['tool','/project/main.gd',1,0,'compiler bridge missing']]};assert.equal((await godot.buildGodotProject('/project')).failureKind,'tool');
assert.equal((await godot.buildGodotProject('/project',()=>true)).interrupted,true);
for(const text of ['config_version=4','config_version=5\nconfig/features=PackedStringArray("C#")']){settings=text;assert.equal((await godot.buildGodotProject('/project')).success,false)}
settings='config_version=5';sidecars=['native.gdextension'];assert.equal((await godot.buildGodotProject('/project')).success,false);sidecars=[];
compiledResult={success:true,info:[]};deferNative=true;const concurrent=godot.buildGodotProject('/project');assert.match((await godot.buildGodotProject('/project')).message,/already running/);deferNative=false;finishNative(compiledResult);assert.equal((await concurrent).success,true);
assert.equal((await godot.buildGodotProject('/project')).success,true);
console.log('PASS: project builds share the native checker, report source locations/capabilities, reject unsupported projects, honor cancellation and release the project lock.');

connected=1;reply={success:true,luaCode:'return 1'};enclosingGodot='/project';
saves=[];r=await buildFile();assert.equal(r.success,true);assert.equal(r.passed,2);
enclosingGodotResult={success:false,file:'/project/project.godot',message:'res://main.gd:2: Parse Error'};
saves=[];r=await buildFile();assert.equal(r.success,false);assert.equal(saves.length,0);
assert.match(r.messages[0].message,/main.gd:2/);
enclosingGodotResult={success:false,file:'/project/project.godot',failureKind:'tool',message:'compiler unavailable'};
r=await buildFile();assert.equal(r.failureKind,'tool');
console.log('PASS: building a Dora wrapper validates its Godot project first and cannot mask Godot failures.');

// File results must survive the real build aggregation, tool handler, model
// history projection and the frontend build-results extraction.
enclosingGodotResult=nativeSuccess;saves=[];const completeBuild=await buildFile();
assert.equal(completeBuild.total,6);assert.equal(completeBuild.passed,6);assert.equal(completeBuild.failed,0);assert.equal(completeBuild.messages.length,6);assert.deepEqual(Array.from(completeBuild.messages,item=>item.file),['project.godot','main.gd','main.tscn','effect.gdshader','common.gdshaderinc','main.ts']);
let handlerBuildResult=completeBuild;
const handlerModule=await load('Assets/Script/Lib/Agent/Tool/Handlers.ts',{__completeBuild:()=>handlerBuildResult},{'Agent/Tools':'module.exports={build:async()=>__completeBuild()};'});
const handlerContext={workingDir:'/project',cancellation:{isCancelled:()=>false},workflow:{}};
const handlerResult=await handlerModule.AGENT_TOOL_HANDLERS.build(handlerContext,{paths:['.']});
const modelContext=projectMessagesForLLMContext([{role:'tool',name:'build',content:JSON.stringify(handlerResult.output)}]);
const seenByModel=JSON.parse(modelContext[0].content);
assert.equal(seenByModel.success,true);assert.equal(seenByModel.results[0].passed,6);assert.equal(seenByModel.results[0].messages.length,6);
assert.ok(seenByModel.results[0].messages.some(item=>item.file.endsWith('main.gd')&&item.success&&item.message.includes('bundled runtime')));
for(const file of ['effect.gdshader','common.gdshaderinc'])assert.ok(seenByModel.results[0].messages.some(item=>item.file===file&&item.success));
const ts=require('typescript');const uiSource=fs.readFileSync(join(root,'Tools/dora-dora/src/AgentStepList.tsx'),'utf8');const uiAst=ts.createSourceFile('AgentStepList.tsx',uiSource,ts.ScriptTarget.Latest,true,ts.ScriptKind.TSX);
const extract=uiAst.statements.find(node=>ts.isFunctionDeclaration(node)&&node.name?.text==='getBuildItems');assert.ok(extract);
const extractJS=ts.transpileModule(extract.getText(uiAst)+';getBuildItems',{compilerOptions:{target:ts.ScriptTarget.ES2022,module:ts.ModuleKind.CommonJS}}).outputText;
const buildUIItems=vm.runInNewContext(extractJS)({result:handlerResult.output});assert.equal(buildUIItems.length,6);assert.ok(buildUIItems.some(item=>item.file.endsWith('main.tscn')&&item.success));
enclosingGodotResult={success:false,file:'/project/main.gd',message:'Parse Error',messages:[{success:true,file:'/project/project.godot',message:'Godot validation passed'},{success:false,file:'/project/main.gd',message:'Parse Error'}]};
saves=[];const partialBuild=await buildFile();assert.equal(partialBuild.success,false);assert.equal(partialBuild.passed,1);assert.equal(partialBuild.failed,1);assert.equal(saves.length,0);
handlerBuildResult=partialBuild;const failedHandlerResult=await handlerModule.AGENT_TOOL_HANDLERS.build(handlerContext,{paths:['.']});assert.equal(failedHandlerResult.output.success,false);assert.equal(handlerContext.workflow.buildRepairPending,true);
const failedModel=JSON.parse(projectMessagesForLLMContext([{role:'tool',name:'build',content:JSON.stringify(failedHandlerResult.output)}])[0].content);assert.equal(failedModel.results[0].passed,1);assert.equal(failedModel.results[0].failed,1);assert.equal(failedModel.results[0].messages.length,2);
console.log('PASS: per-file Godot success logs bypass Agent debug filtering; file details/counts reach the real Agent handler, model history and build-results UI; partial failures retain earlier successes and block wrapper compilation.');

enclosingGodotResult={success:false,file:'/project/effect.gdshader',message:'res://common.gdshaderinc:2:0: Invalid return type',messages:[{success:true,file:'/project/project.godot',message:'Godot validation passed'},{success:false,file:'/project/effect.gdshader',message:'res://common.gdshaderinc:2:0: Invalid return type'}]};
handlerBuildResult=await buildFile();const shaderHandler=await handlerModule.AGENT_TOOL_HANDLERS.build(handlerContext,{paths:['.']});
const shaderModel=JSON.parse(projectMessagesForLLMContext([{role:'tool',name:'build',content:JSON.stringify(shaderHandler.output)}])[0].content);
assert.equal(shaderModel.success,false);assert.match(shaderModel.results[0].messages.at(-1).message,/common\.gdshaderinc:2:0/);
assert.ok(vm.runInNewContext(extractJS)({result:shaderHandler.output}).some(item=>!item.success&&item.message.includes('common.gdshaderinc:2:0')));
console.log('PASS: shader/include success and nested diagnostic details survive Agent aggregation, model history and build-results UI.');

// A compiler capability/path failure with file diagnostics must retain the
// build result, rather than throw away its messages as a step exception.
handlerBuildResult={success:false,failureKind:'tool',message:'compiler bridge missing',total:2,passed:1,failed:1,messages:[{success:true,file:'project.godot',message:'Godot validation passed'},{success:false,file:'main.gd',failureKind:'tool',message:'compiler bridge missing'}]};
const bridgeFailure=await handlerModule.AGENT_TOOL_HANDLERS.build(handlerContext,{paths:['.']});
assert.equal(bridgeFailure.output.success,false);assert.equal(handlerContext.workflow.lastBuildSucceeded,false);assert.equal(handlerContext.workflow.buildRepairPending,true);
const bridgeModel=JSON.parse(projectMessagesForLLMContext([{role:'tool',name:'build',content:JSON.stringify(bridgeFailure.output)}])[0].content);
assert.equal(bridgeModel.results[0].messages.length,2);assert.equal(bridgeModel.results[0].failed,1);
assert.ok(vm.runInNewContext(extractJS)({result:bridgeFailure.output}).some(item=>item.file==='main.gd'&&!item.success&&item.message==='compiler bridge missing'));
console.log('PASS: tool-level compiler diagnostics retain file cards, model details and completion blocking.');
