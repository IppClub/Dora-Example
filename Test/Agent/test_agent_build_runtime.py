"""Run isolated registered build tools in the current native Dora service; no LLM tasks."""
import json, pathlib, tempfile, urllib.request, shutil, time
root=pathlib.Path(tempfile.mkdtemp(prefix='dora-build-contract-'))
(root/'init.ts').write_text('export const ready = true;\n')
(root/'good.ts').write_text('export const value: number = 1;\n')
(root/'bad.ts').write_text('export const value: number = "wrong";\n')
(root/'warning.ts').write_text('export function fallback(value: number): number { return value || 1; }\n')
(root/'types.d.ts').write_text('declare const n: number;\n')
(root/'good.lua').write_text('return 1\n')
(root/'bad.lua').write_text('local = broken\n')
(root/'empty').mkdir()
code='''
local names={"Agent.Tool.Build","Agent.Tools","Agent.Tool.Handlers","Agent.Tool.Registry","Agent.Tool.Executor","Agent.Runtime.HistoryProjection","Agent.Runtime.SessionEvents","Agent.DoraAgent"}
local oldStream,T,oldToolsBuild
local old={}
for _,name in ipairs(names) do old[name]=package.loaded[name]; package.loaded[name]=nil end
local U=require("Agent.Utils")
local D=require("Dora")
D.thread(function()
local ok,err=pcall(function()
local E=require("Agent.Tool.Executor")
local H=require("Agent.Runtime.HistoryProjection")
local U=require("Agent.Utils")
local function await(p)
 local done,result,failure=false,nil,nil
 p:addCallbacks(function(_,r) result=r; done=true end,function(_,e) failure=tostring(e);done=true end)
 while not done do sleep() end
 assert(not failure,failure)
 return result
end
local context={taskId=0,step=1,workingDir=projectDir,role="main",workMode="code",useChineseResponse=false,disabledAgentTools={},workflow={},services={},cancellation={stopToken={stopped=false},isCancelled=function() return false end,reason=function() return nil end},emitProgress=function() end}
local function run(paths)
 return await(E.executeRegisteredAgentTool({tool="build",input={paths=paths},context=context,schemaContext={searchDoraDocLimitMax=20}}))
end
local function check(paths,expected)
 local execution=run(paths)
 local result=execution.output
 assert(execution.execution.status=="DONE")
 assert(result.success==expected,U.safeJsonEncode(result))
 print(U.safeJsonEncode({paths=paths,result=H.projectBuildResultForModel(result,execution.execution)}))
 return result
end
check({"good.ts"},true)
check({"bad.ts"},false)
check({"warning.ts"},false)
check({"good.lua"},true)
check({"bad.lua"},false)

check({"types.d.ts"},false)
check({"empty"},false)
local mixed=check({"good.lua","bad.lua"},false)
assert(mixed.partial==true and mixed.succeededBuildCount==1)
local failure=H.projectBuildResultForModel({success=false,code="TOOL_EXECUTION_FAILED",message="controlled bridge failure"},{status="FAILED"})
assert(failure.success==nil and failure.code==nil and failure.message=="Build tool call failed: controlled bridge failure")
T=require("Agent.Tools")
oldToolsBuild=T.build
local policy=require("Agent.Runtime.CompletionPolicy")
local l=require("lualib_bundle")
local cancelled=false
context.cancellation.isCancelled=function() return cancelled end
context.cancellation.reason=function() return "controlled cancellation" end
T.build=function(req)
 cancelled=true
 error("controlled interrupted build")
end
local stopped=run({"good.lua"})
assert(stopped.execution.status=="STOPPED" and stopped.output.code=="TOOL_CANCELLED")
assert(context.workflow.hasBuilt==true and context.workflow.lastBuildSucceeded==false)
assert(policy.getAuthoredCompletionBlocker(context.workflow)~=nil)
cancelled=false
T.build=oldToolsBuild
local resumed=run({"good.lua"})
assert(resumed.execution.status=="DONE" and resumed.output.success==true)
assert(policy.getAuthoredCompletionBlocker(context.workflow)==nil)
for _,mode in ipairs({"throw","reported"}) do
 context.workflow={}
 T.build=function(req)
  if mode=="throw" then error("controlled build invocation failure") end
  return l.__TS__Promise.resolve({success=false,failureKind="tool",message="controlled reported failure"})
 end
 local failed=run({"good.lua"})
 assert(failed.execution.status=="FAILED")
 assert(context.workflow.hasBuilt==true and context.workflow.lastBuildSucceeded==false)
 assert(policy.getAuthoredCompletionBlocker(context.workflow)~=nil)
 local model=H.projectBuildResultForModel(failed.output,failed.execution)
 assert(model.success==nil and model.code==nil and model.message:find("controlled",1,true))
 T.build=oldToolsBuild
 local retry=run({"good.lua"})
 assert(retry.execution.status=="DONE" and retry.output.success==true)
 assert(policy.getAuthoredCompletionBlocker(context.workflow)==nil)
end
local executions=0
T.build=function(req)
 executions=executions+1
 if executions==1 then error("controlled build invocation failure") end
 return oldToolsBuild(req)
end
oldStream=U.callLLMStreamAggregated
local calls,events=0,{}
local l=require("lualib_bundle")
U.callLLMStreamAggregated=function(messages)
 calls=calls+1
 if calls==2 then
  local observed
  for _,m in ipairs(messages) do if m.role=="tool" and m.name=="build" then observed=U.safeJsonDecode(m.content) end end
  assert(observed and observed.success==nil and observed.code==nil and observed.execution==nil)
  assert(observed.message:find("controlled build invocation failure",1,true))
 end
 if calls==2 then
  return l.__TS__Promise.resolve({success=true,response={choices={{finish_reason="stop",message={content="Premature completion attempt."}}}}})
 end
 if calls==3 then
  local blocked=false
  for _,m in ipairs(messages) do if type(m.content)=="string" and m.content:find("latest project build failed",1,true) then blocked=true end end
  assert(blocked,"premature completion was not rejected")
 end
 if calls==1 or calls==3 then
  local args=U.safeJsonEncode({paths={"good.lua"}})
  return l.__TS__Promise.resolve({success=true,response={choices={{finish_reason="tool_calls",message={tool_calls={{id="build-"..calls,type="function",["function"]={name="build",arguments=args}}}}}}}})
 end
 assert(calls==4,"unexpected extra model request")
 return l.__TS__Promise.resolve({success=true,response={choices={{finish_reason="stop",message={content="Controlled regression complete."}}}}})
end
local finished
require("Agent.DoraAgent").runCodingAgent({taskId=0,workDir=projectDir,prompt="Build the existing project and report the result.",llmConfig={url="http://unused.invalid",apiKey="test-only",model="test-only",contextWindow=128000,maxTokens=2048,temperature=0.1,supportsFunctionCalling=true},onEvent=function(_,event) if event.type=="tool_finished" then events[#events+1]=event end end},function(result) finished=result end)
while not finished do sleep() end
assert(finished.success,U.safeJsonEncode(finished))
assert(calls==4 and executions==2)
assert(events[1].execution.status=="FAILED" and events[2].execution.status=="DONE")
assert(events[2].result.success==true)
print("BUILD_FAILURE_CONTINUATION_PASS")
print("BUILD_CONTRACT_RUNTIME_PASS")
end)
if oldStream then U.callLLMStreamAggregated=oldStream end
if T and oldToolsBuild then T.build=oldToolsBuild end
for _,name in ipairs(names) do package.loaded[name]=old[name] end
D.Content:save(projectDir .. "/runtime-result.json", U.safeJsonEncode({success=ok,message=tostring(err)}))
end)
print("BUILD_CONTRACT_RUNTIME_STARTED")
'''
op=urllib.request.build_opener(urllib.request.ProxyHandler({}))
try:
 req=urllib.request.Request('http://127.0.0.1:8866/agent/command',data=json.dumps({'projectRoot':str(root),'mode':'lua','code':code,'timeoutSeconds':120}).encode(),headers={'Content-Type':'application/json'})
 result=json.load(op.open(req,timeout=150))
 assert result['success'],result
 assert 'BUILD_CONTRACT_RUNTIME_STARTED' in result['output'],result
 deadline=time.monotonic()+100
 while not (root/'runtime-result.json').exists() and time.monotonic()<deadline: time.sleep(0.2)
 assert (root/'runtime-result.json').exists(), 'Background build contract test timed out'
 final=json.loads((root/'runtime-result.json').read_text())
 assert final['success'],final
 assert not (root/'bad.lua').read_text().startswith('-- [ts]')
 assert not (root/'warning.lua').exists()
 assert (root/'good.lua').read_text().startswith('-- [ts]')

 print('PASS: background registered build tool: TypeScript success/error/warning, Lua syntax, declarations, empty/mixed builds model projection, generic execution metadata and completion blocking for thrown/reported failures and Agent continuation after rejected premature completion.')
finally: shutil.rmtree(root)
