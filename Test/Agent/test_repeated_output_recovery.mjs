import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {createRequire} from 'node:module';
import {join} from 'node:path';
import vm from 'node:vm';
const root = process.env.DORA_SSR_ROOT;
if (!root) throw Error('Set DORA_SSR_ROOT to the Dora-SSR checkout.');
const require = createRequire(join(root, 'Tools/dora-dora/package.json'));
const {build} = require('esbuild');
const fixture = JSON.parse(await readFile(new URL('./Fixtures/task670-responses.json', import.meta.url), 'utf8'));
const globals = {Math, Map, Set, Promise, console, math:Math, tostring:String, os:{time:()=>1,date:()=> 'test'},
 setmetatable:Object.setPrototypeOf, getmetatable:Object.getPrototypeOf};
let nextResponse, requests=[], executed=[];
const identity = x => x;
const utils = {Log(level,message){if(level==="Error")console.error(message)}, sanitizeUTF8:identity, safeJsonEncode:x=>[JSON.stringify(x)], safeJsonDecode:s=>[JSON.parse(s)],
 normalizeAgentCompletionReport:identity,fitMessagesToContext:()=>({originalTokens:1,budgetTokens:100000}), estimateTextTokens:()=>1, createLocalToolCallId:()=> 'local',
 callLLMStreamAggregated:async (messages, options, token, config, onStream, onTool) => {
  assert.equal(onTool, undefined, 'tools must never execute from streaming callbacks');
  requests.push(structuredClone(messages));
  if(requests.length>4)requests.shift();
  onStream?.({choices:[{message:nextResponse}]});
  return {success:true,response:{choices:[{message:nextResponse,finish_reason:'tool_calls'}]}};
 }};
const registry={buildRoleToolDefinitionsDetailed:()=>"",buildDecisionToolSchema:()=>[],getAllowedToolsForRole:()=>['read_file','execute_command','save_memory','edit_file'],isKnownToolName:()=>true,
 buildCurrentToolAvailabilityGuidance:()=>"",canRunToolInParallel:()=>false,canPreExecuteTool:()=>true};
const parsing={parseToolCallArguments:(_,s)=>JSON.parse(s),parseDecisionToolCall:(tool,params)=>({success:true,tool,params}),
 parseXMLToolCallObjectFromText:()=>({success:true,obj:{tool:'read_file',params:{path:'Script/render.ts',startLine:300}}}),
 parseDecisionObject:obj=>({success:true,...obj}),parseMainXMLCompletion:()=>undefined,
 validateDecision:(_,params)=>({success:true,params}),validateCompletionForRole:()=>({success:true}),
 isDecisionBatchSuccess:x=>x.kind==='batch',isDecisionLoopContinue:x=>x.kind==='loop_continue',isDecisionPlainTextCompletion:x=>x.kind==='plain_text'};
const projection = new Proxy({toJson:JSON.stringify,truncateText:x=>x,sanitizeActionParamsForHistory:(_,p)=>p,
 sanitizeReadResultForHistory:(_,r)=>r,sanitizeToolActionResultForHistory:(_,r)=>r}, {get:(obj,key)=>obj[key]??identity});
for (const key of ['sanitizeMessagesForLLMInput','projectMessagesForLLMContext','projectMessagesForCompression','sanitizeSearchResultForHistory','sanitizeListFilesResultForHistory','sanitizeBuildResultForHistory','projectBuildResultForModel']) projection[key]=identity;
const modules={Dora:{Content:{exist:()=>false,load:()=>'',getFiles:()=>[]},Path:Object.assign((...x)=>x.join('/'),{getExt:()=> 'ts'})},
 'Agent/Runtime/Policy':{getUncoveredConversationMessages:(m,i)=>m.slice(i)},
 'Agent/Utils':utils,'Agent/Tool/Registry':registry,'Agent/Runtime/DecisionParsing':parsing,
 'Agent/Runtime/HistoryProjection':projection,'Agent/Runtime/StepDebugLog':{encodeDebugJSON:JSON.stringify,saveStepLLMDebugInput(){},saveStepLLMDebugOutput(){}},
 'Agent/Runtime/StepBudget':{getRemainingAgentWorkSteps:()=>Infinity,isFinalAgentDecisionTurn:()=>false},
 'Agent/Runtime/CompletionPolicy':{getAuthoredCompletionBlocker:()=>undefined},
 'Agent/Tool/Batch':{partitionAgentToolCalls:actions=>[{actions,isConcurrencySafe:false}]},
 'Agent/Config/Defaults':{AGENT_LIMITS:{searchDoraDocLimitMax:20},AGENT_DEFAULTS:{}},
 'Agent/Tools':{setTaskStatus(){}},
 'Agent/Tool/VisionBinding':{resolveVisionBinding:()=>({})},
 'Agent/Tool/Executor':{executeRegisteredAgentTool:async ({tool,input})=>{executed.push({tool,input});return {execution:{status:'DONE'},output:{success:true,content:'actual replay observation'}};}}};
const bundled = await build({entryPoints:[join(root,'Assets/Script/Lib/Agent/DoraAgent.ts')],bundle:true,write:false,format:'cjs',platform:'node',plugins:[{name:'isolated-dependencies',setup(b){
 b.onResolve({filter:/^(Dora|Agent\/)/},a=>{
  if (['Agent/Runtime/RepeatedOutput','Agent/Runtime/Flow'].includes(a.path)) return {path:join(root,'Assets/Script/Lib',a.path+'.ts')};
  return {path:a.path,namespace:'stub'};
 });
 b.onLoad({filter:/.*/,namespace:'stub'},a=>({contents:`module.exports=__modules[${JSON.stringify(a.path)}]??{};`,loader:'js'}));
 b.onLoad({filter:/\/DoraAgent\.ts$/},async a=>({contents:await readFile(a.path,'utf8')+'\nexport {MainDecisionAgent, BatchToolAction, compactAllHistory, finalizeAgentFailure};',loader:'ts'}));
}}]});
const box={...globals,__modules:modules,module:{exports:{}},exports:{}};
vm.runInNewContext(bundled.outputFiles[0].text,box);
const {MainDecisionAgent,BatchToolAction,compactAllHistory,finalizeAgentFailure}=box.module.exports;
const pure = await build({entryPoints:[join(root,'Assets/Script/Lib/Agent/Runtime/RepeatedOutput.ts')],bundle:true,write:false,format:'cjs',platform:'node'});
const pureBox={module:{exports:{}},exports:{}};vm.runInNewContext(pure.outputFiles[0].text,pureBox);
const {RepeatedOutputRecovery,decisionOutputKey}=pureBox.module.exports;
let pairs=0;
for (let i=1;i<fixture.responses.length;i++) if(decisionOutputKey(fixture.responses[i-1].message)===decisionOutputKey(fixture.responses[i].message))pairs++;
assert.equal(fixture.taskId,670);assert.equal(fixture.responses.length,162);assert.equal(pairs,125);
function shared({failure=false,partial=false,cancel=false,noProgress=false}={}) {
 const events=[],archives=[],writes=[];
 const s={taskId:670,sessionId:261,workingDir:'/replay',userQuery:'Continue the TypeScript game',useChineseResponse:false,
  role:'main',decisionMode:'tool_calling',workMode:'code',maxSteps:Infinity,agentStepCount:0,step:0,llmMaxTry:5,
  stopToken:{stopped:false},llmConfig:{model:'replay',contextWindow:128000},llmOptions:{},promptPack:{},disabledAgentTools:[],
  messages:[{role:'user',content:'Continue the TypeScript game'}],history:[],lastConsolidatedIndex:0,workflow:{},
  repeatedOutput:new RepeatedOutputRecovery(),onEvent:e=>events.push(e)};
 const storage={getRelevantMemoryContext:()=>'',writeSessionState:(m,i)=>writes.push({messageCount:m.length,index:i})};
 s.memory={compressor:{getMaxCompressionRounds:()=>3,getMemoryContextBudget:()=>100,getStorage:()=>storage,
  compress:async (messages,opts,tries,mode,debug,strategy)=>{
   assert.equal(strategy,'budget_max');archives.push(structuredClone(messages));
   if(cancel){s.stopToken.stopped=true;s.stopToken.reason='user cancellation';}
   if(failure)return {success:false,error:'controlled compression failure'};
   return {success:true,compressedCount:noProgress?0:partial?Math.min(2,messages.length):messages.length,summary:'Archived actual observations',sessionSummaryUpdate:'Goal: finish game. Current evidence: first tool observation. Continue with next action.'};
  }}};
 return {s,events,archives,writes};
}
async function turn(s,message) {
 nextResponse=message;const node=new MainDecisionAgent();const decision=await node.exec({shared:s});
 const route=await node.post(s,undefined,decision);
 if(route==='batch_tools') {const batch=new BatchToolAction();const input=await batch.prep(s);await batch.exec(input);await batch.post(s);}
 return {decision,route};
}
const repeated=fixture.responses.filter(r=>['4_1_out.md','5_1_out.md','6_1_out.md'].includes(r.file));
assert.equal(repeated.length,3);
// Replay actual calls through the real decision -> tool execution -> compaction path.
executed=[];requests=[];let t=shared();
await turn(t.s,repeated[0].message);assert.equal(executed.length,1);
const originalHistory=structuredClone(t.s.messages);
const second=await turn(t.s,repeated[1].message);
assert.equal(second.route,'main');assert.equal(executed.length,1);assert.equal(t.archives.length,1);
assert.equal(t.s.lastConsolidatedIndex,t.s.messages.length);assert.equal(JSON.stringify(t.s.messages),JSON.stringify(originalHistory));
assert.equal(t.s.taskId,670);assert.equal(t.s.stopToken.stopped,false);
const third=await turn(t.s,repeated[2].message);
assert.equal(third.route,'done');assert.equal(executed.length,1);assert.equal(t.archives.length,1);
assert.equal(t.s.stopToken.stopped,true);assert.match(t.s.stopToken.reason,/recovery was ineffective/);
const stopped=finalizeAgentFailure(t.s,'ignored');assert.equal(stopped.success,false);
assert.ok(t.events.some(e=>e.type==='task_finished' && e.message.includes('Task paused')));
assert.ok(!requests.at(-1).some(m=>m.role==='tool'), 'post-compaction decision must not include old tool observations');
// XML complete-response path uses the same gate before repair or execution.
executed=[];t=shared();t.s.decisionMode='xml';
const xml={content:'<tool_call><tool>read_file</tool><params><path>Script/render.ts</path></params></tool_call>'};
await turn(t.s,xml);await turn(t.s,xml);assert.equal(executed.length,1);assert.equal(t.archives.length,1);
await turn(t.s,xml);assert.equal(t.s.stopToken.stopped,true);assert.equal(executed.length,1);
// Successful recovery: fresh different call executes in the SAME task.
executed=[];t=shared({partial:true});await turn(t.s,repeated[0].message);await turn(t.s,repeated[1].message);
const different={tool_calls:[{id:'new',function:{name:'read_file',arguments:'{"path":"Script/game.ts"}'}}]};
await turn(t.s,different);assert.equal(executed.length,2);assert.equal(t.s.taskId,670);assert.equal(t.s.stopToken.stopped,false);
assert.ok(t.archives.length>=1);assert.ok(t.writes.length>0);
// Compression failure/cancellation must not execute the blocked call or mark the task successful.
for(const options of [{failure:true},{noProgress:true},{cancel:true}]){executed=[];t=shared(options);await turn(t.s,repeated[0].message);await turn(t.s,repeated[1].message);assert.equal(executed.length,1);assert.equal(t.s.stopToken.stopped,true);if(options.cancel)assert.equal(t.s.stopToken.reason,'user cancellation');}
// Manual /compact retains its task-completion behavior.
t=shared();await compactAllHistory(t.s);assert.ok(t.events.some(e=>e.type==='task_finished'&&e.success));
// Full real history: changing IDs alone cannot bypass detection; no fuzzy matches.
let detector=new RepeatedOutputRecovery(),intercepts=0;
for (const row of fixture.responses){const action=detector.observe(row.message);if(action==='compact')intercepts++;}
assert.ok(intercepts>0);
detector=new RepeatedOutputRecovery();assert.equal(detector.observe(different),'accept');
assert.equal(detector.observe({...different,tool_calls:[{...different.tool_calls[0],id:'other'}]}),'compact');
assert.equal(detector.observe({...different,content:'different text'}),'accept');
assert.equal(detector.observe({...different,reasoning_content:'different reasoning'}),'accept');
assert.equal(detector.observe({...different,tool_calls:[{function:{name:'read_file',arguments:'{ "path":"Script/game.ts"}'}}]}),'accept');
// A long sequence of distinct decisions continues beyond 999 tools; recovery adds no step cap.
executed=[];t=shared();
for(let i=0;i<1100;i++)await turn(t.s,{tool_calls:[{id:String(i),function:{name:'read_file',arguments:JSON.stringify({path:`file${i}.ts`})}}]});
assert.equal(executed.length,1100);assert.equal(t.archives.length,0);assert.equal(t.s.stopToken.stopped,false);
// Without a different successful tool, alternating repetition cannot endlessly compact.
detector=new RepeatedOutputRecovery();
assert.equal(detector.observe({content:'A'}),'accept');assert.equal(detector.observe({content:'A'}),'compact');
assert.equal(detector.observe({content:'B'}),'accept');assert.equal(detector.observe({content:'B'}),'compact');
assert.equal(detector.observe({content:'A'}),'accept');assert.equal(detector.observe({content:'A'}),'pause');
console.log(`PASS: task670 actual history (${fixture.responses.length} responses, ${pairs} identical adjacent pairs), execution-before-intercept prevention, forced full compaction, same-task resume, ineffective recovery STOPPED, failure/cancellation, manual compact.`);
