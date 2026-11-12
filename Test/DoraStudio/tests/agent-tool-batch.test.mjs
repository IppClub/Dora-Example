import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import vm from 'node:vm';
import ts from 'typescript';

// Exercise the original decision entry and batch executor; only model/I/O are adapters.
const path='../Assets/Script/Lib/Agent/';
const source=ts.createSourceFile('DoraAgent.ts',await readFile(path+'DoraAgent.ts','utf8'),ts.ScriptTarget.Latest,true);
const classes=source.statements.filter(ts.isClassDeclaration);
const decision=classes.find(c=>c.name?.text==='MainDecisionAgent').members.find(m=>m.name?.getText(source)==='callDecisionByToolCalling');
const batch=classes.find(c=>c.name?.text==='BatchToolAction');
const batchSource=await readFile(path+'Tool/Batch.ts','utf8');
const text=`${batchSource.replace(/^import .*;$/mg,'').replace(/^export /mg,'')}\nclass DecisionUnderTest {${decision.getText(source)}}\n${batch.getText(source)}\nglobalThis.api={DecisionUnderTest,BatchToolAction,partitionAgentToolCalls};`;
const code=ts.transpileModule(text,{compilerOptions:{target:ts.ScriptTarget.ES2022,module:ts.ModuleKind.None}}).outputText;
function fixture(calls=[]){
 const starts=[],finishes=[],pending=new Map();
 const shared={role:'main',step:0,agentStepCount:0,maxSteps:20,llmConfig:{model:'fixture'},llmOptions:{},stopToken:{stopped:false},workflow:{}};
 const box={Node:class{},Promise,Map,Set,Math,math:Math,
  AgentConfig:{AGENT_LIMITS:{searchDoraDocLimitMax:20}},
  AgentToolRegistry:{buildDecisionToolSchema:()=>[],canRunToolInParallel:tool=>['read_file','grep_files','search_dora_doc'].includes(tool)},
  AgentUtils:{Log(){},sanitizeUTF8:x=>x,callLLMStreamAggregated:async()=>({success:true,response:{choices:[{finish_reason:'tool_calls',message:{tool_calls:calls}}]}})},
  getDecisionDisabledAgentTools:()=>[],buildDecisionMessages:()=>[],getRemainingAgentWorkSteps:()=>20,
  emitLLMContextMetrics(){},saveStepLLMDebugInput(){},saveStepLLMDebugOutput(){},recordLLMTokenUsage(){},encodeDebugJSON:JSON.stringify,
  emitAssistantMessageUpdated(){},interceptRepeatedOutput:async()=>undefined,
  parseAndValidateToolCallDecision:(_shared,tool,args,toolCallId)=>({success:true,tool,params:JSON.parse(args),toolCallId,
   ...(tool==='invalid'?{preExecutionFailure:{code:'INVALID_TOOL_INPUT',message:'fixture rejection'}}:{})}),
  appendToolResultMessage(){},emitAgentStartEvent:(_,a)=>starts.push(a.toolCallId),emitAgentFinishEvent:(_,a)=>finishes.push(a.toolCallId),emitCheckpointEventForAction(){},persistHistoryState(){},
  sanitizeActionParamsForHistory:(_,p)=>p,sanitizeToolActionResultForHistory:(_,r)=>r,
  executeToolActionSafely:(_,a)=>new Promise(resolve=>pending.set(a.toolCallId,()=>resolve({success:true,id:a.toolCallId}))),
 };
 vm.createContext(box);vm.runInContext(code,box);
 return {shared,box,starts,finishes,pending,...box.api};
}
const call=(tool,id)=>({id,function:{name:tool,arguments:'{}'}});
const plain=x=>JSON.parse(JSON.stringify(x));
const tick=()=>new Promise(resolve=>setImmediate(resolve));

test('multiple ordinary calls survive decision admission, including serialized writes',async()=>{
 for(const names of [['grep_files','grep_files','grep_files'],['read_file','write_file','grep_files']]){
  const f=fixture(names.map((tool,i)=>call(tool,String(i))));
  const result=await new f.DecisionUnderTest().callDecisionByToolCalling(f.shared);
  assert.equal(result.kind,'batch');assert.deepEqual(plain(result.decisions.map(d=>d.tool)),names);
  assert.ok(result.decisions.every(d=>d.preExecutionFailure===undefined));
 }
});
test('single calls and per-call failures retain their original handling',async()=>{
 let f=fixture([call('grep_files','one')]);
 let result=await new f.DecisionUnderTest().callDecisionByToolCalling(f.shared);
 assert.equal(result.tool,'grep_files');assert.equal(result.kind,undefined);
 f=fixture([call('invalid','bad'),call('read_file','good')]);
 result=await new f.DecisionUnderTest().callDecisionByToolCalling(f.shared);
 assert.equal(result.decisions[0].preExecutionFailure.code,'INVALID_TOOL_INPUT');
 assert.equal(result.decisions[1].preExecutionFailure,undefined);
});
test('ask_user is accepted in any position and deferred without reordering ordinary calls',async()=>{
 for(const names of [['ask_user','grep_files','read_file'],['read_file','ask_user','write_file','grep_files'],['grep_files','ask_user']]){
  const f=fixture(names.map((tool,i)=>call(tool,String(i))));
  const result=await new f.DecisionUnderTest().callDecisionByToolCalling(f.shared);
  assert.ok(result.decisions.every(d=>d.preExecutionFailure===undefined));
  assert.deepEqual(plain(result.decisions.map(d=>d.tool)),[...names.filter(n=>n!=='ask_user'),'ask_user']);
  assert.deepEqual(plain(result.decisions.map(d=>d.toolCallId)),[...names.map((n,i)=>[n,String(i)]).filter(([n])=>n!=='ask_user').map(([,id])=>id),String(names.indexOf('ask_user'))]);
 }
 const single=fixture([call('ask_user','question')]);
 assert.equal((await new single.DecisionUnderTest().callDecisionByToolCalling(single.shared)).toolCallId,'question');
});
test('deferred ask_user waits for all preceding reads and uses existing waiting transition',async()=>{
 const f=fixture([call('ask_user','question'),call('grep_files','read1'),call('read_file','read2')]);
 const result=await new f.DecisionUnderTest().callDecisionByToolCalling(f.shared);
 const actions=result.decisions.map(d=>({...d,params:{}}));
 const run=new f.BatchToolAction();const promise=run.exec({shared:f.shared,actions});
 await tick();assert.deepEqual(f.starts,['read1','read2']);
 f.pending.get('read2')();await tick();assert.deepEqual(f.starts,['read1','read2']);
 f.pending.get('read1')();await tick();assert.deepEqual(f.starts,['read1','read2','question']);
 f.shared.workflow.waitingQuestionnaireId=42;f.pending.get('question')();await promise;
 assert.equal(await run.post(f.shared), 'done');
 assert.equal(f.shared.pendingToolActions,undefined);
 assert.deepEqual(f.finishes,['read1','read2','question']);
});
test('real batch executor overlaps adjacent reads but never crosses a write barrier',async()=>{
 const f=fixture();
 const actions=['grep_files','read_file','write_file','grep_files'].map((tool,i)=>({tool,toolCallId:String(i),params:{}}));
 const promise=new f.BatchToolAction().exec({shared:f.shared,actions});
 await tick();assert.deepEqual(f.starts,['0','1']);
 f.pending.get('1')();await tick();assert.deepEqual(f.starts,['0','1']);
 f.pending.get('0')();await tick();assert.deepEqual(f.starts,['0','1','2']);
 assert.deepEqual(f.finishes,['0','1'],'persist results in declared order despite reversed completion');
 f.pending.get('2')();await tick();assert.deepEqual(f.starts,['0','1','2','3']);
 f.pending.get('3')();const result=await promise;
 assert.deepEqual(plain(result.map(a=>a.result.id)),['0','1','2','3']);
});

test('mixed calls are deferred until the full model response completes',async()=>{
 const calls=[call('ask_user','question'),call('grep_files','read')];
 const f=fixture(calls);let complete,settled=false;
 f.box.AgentUtils.callLLMStreamAggregated=async(_messages,_options,_stop,_config,onStream)=>{
  onStream({choices:[{message:{content:'partial',tool_calls:[calls[0]]}}]});
  return new Promise(resolve=>{complete=()=>resolve({success:true,response:{choices:[{finish_reason:'tool_calls',message:{tool_calls:calls}}]}});});
 };
 const pending=new f.DecisionUnderTest().callDecisionByToolCalling(f.shared).then(result=>{settled=true;return result;});
 await tick();assert.equal(settled,false);assert.deepEqual(f.starts,[]);
 complete();const result=await pending;
 assert.deepEqual(plain(result.decisions.map(d=>d.toolCallId)),['read','question']);
});
