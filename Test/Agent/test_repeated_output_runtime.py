"""Opt-in native replay: dedicated idle Dora Debug service; no external LLM requests."""
import json, pathlib, tempfile, urllib.request, shutil, time
fixture=json.loads((pathlib.Path(__file__).parent/'Fixtures/task670-responses.json').read_text())
responses=[r['message'] for r in fixture['responses'] if r['file'] in ['4_1_out.md','5_1_out.md','6_1_out.md']]
root=pathlib.Path(tempfile.mkdtemp(prefix='dora-repeat670-'))
(root/'Script').mkdir()
(root/'Script/render.ts').write_text('\n'.join('export const n%d = %d;'%(i,i) for i in range(320)))
(root/'Script/game.ts').write_text('export const state = "ready";\n')
(root/'init.lua').write_text('return true\n')
(root/'responses.json').write_text(json.dumps(responses))
code=r'''
local H=require("Script.Dev.AgentHost")
assert(not H.status().pending,"finish pending source reload before native test")
local release=H.acquire()
local U=require("Agent.Utils")
local l=require("lualib_bundle")
local D=require("Dora")
local oldCall,oldStream=U.callLLM,U.callLLMStreamAggregated
local oldModules={}
local names={"Agent.Runtime.Memory","Agent.DoraAgent","Agent/Runtime/Memory","Agent/DoraAgent"}
for _,name in ipairs(names) do oldModules[name]=package.loaded[name];package.loaded[name]=nil end
local rows=assert(U.safeJsonDecode(D.Content:load(projectDir.."/responses.json")))
local scenario,calls,compressions,events,latest=0,0,0,{},nil
local function response(message)
 return l.__TS__Promise.resolve({success=true,response={choices={{finish_reason=message.tool_calls and "tool_calls" or "stop",message=message}}}})
end
U.callLLM=function(messages,options)
 assert(options.tools and #options.tools==1 and options.tools[1]["function"].name=="save_memory","unexpected non-decision LLM request")
 compressions=compressions+1
 return response({role="assistant",tool_calls={{id="compression",type="function",["function"]={name="save_memory",arguments=U.safeJsonEncode({history_entry="Native replay: first render.ts read succeeded; repeated call intercepted before execution.",memory_update="# Memory\nNative deterministic regression.",project_memory_update="# Project\nTypeScript fixture files exist.",session_summary_update="# Session Summary\nGoal: inspect fixture, then finish.\nFirst read completed; no source edits.\n## Active Checkpoint\n**Next tool**: read_file\nRead Script/game.ts next."})}}}})
end
U.callLLMStreamAggregated=function(messages,options,token,config,onStream,onTool)
 assert(onTool==nil,"streaming tool execution bypassed the gate")
 calls=calls+1
 local message
 if scenario==1 then
  assert(calls<=3,"ineffective recovery continued making requests")
  message=rows[calls]
 else
  if scenario==2 and calls<=2 then message=rows[calls]
  elseif (scenario==2 and calls==3) or (scenario==3 and calls==1) then
   message={role="assistant",tool_calls={{id="new-read",type="function",["function"]={name="read_file",arguments='{"path":"Script/game.ts"}'}}}}
  else message={role="assistant",content="Native deterministic replay complete."} end
 end
 if onStream then onStream({choices={{message=message}}}) end
 return response(message)
end
D.thread(function()
 local ok,err=pcall(function()
  local A=require("Agent.DoraAgent")
  local function run(scope,resume)
   latest=nil;events={};calls=0;compressions=0
   local token={stopped=false}
   A.runCodingAgent({taskId=0,workDir=projectDir,prompt=resume and "" or "Inspect the TypeScript fixtures and report.",memoryScope=scope,resumeConversation=resume,maxSteps=math.huge,stopToken=token,llmConfig={url="http://unused.invalid",apiKey="test-only",model="replay",contextWindow=128000,maxTokens=2048,temperature=0,supportsFunctionCalling=true},onEvent=function(_,e) events[#events+1]=e end},function(r) latest=r end)
   while not latest do sleep() end
   local tools=0
   for _,e in ipairs(events) do if e.type=="tool_finished" then tools=tools+1;assert(e.execution.status=="DONE" and e.result.success) end end
   return token,tools
  end
  scenario=1
  local token,tools=run("native-stop",false)
  assert(not latest.success and token.stopped and latest.message:find("recovery was ineffective",1,true),U.safeJsonEncode(latest))
  assert(calls==3 and tools==1 and compressions==1,"duplicate executed or compression looped")
  local stoppedResult=latest
  scenario=3
  token,tools=run("native-stop",true)
  assert(latest.success and not token.stopped and tools==1,"paused task could not continue")
  scenario=2
  token,tools=run("native-success",false)
  assert(latest.success and not token.stopped and calls==4 and tools==2 and compressions==1,"same-task recovery did not continue")
  D.Content:save(projectDir.."/native-summary.json",U.safeJsonEncode({success=true,stoppedMessage=stoppedResult.message,continued=true,sameTaskRecovered=true}))
 end)
 U.callLLM,U.callLLMStreamAggregated=oldCall,oldStream
 for _,name in ipairs(names) do package.loaded[name]=oldModules[name] end
 release()
 D.Content:save(projectDir.."/runtime-result.json",U.safeJsonEncode({success=ok,message=tostring(err)}))
end)
print("REPEAT670_NATIVE_STARTED")
'''
op=urllib.request.build_opener(urllib.request.ProxyHandler({}))
try:
 status=json.load(op.open(urllib.request.Request('http://127.0.0.1:8866/agent/runtime/status',data=b'{}',headers={'Content-Type':'application/json'}),timeout=5))
 assert not status['busy'],status
 req=urllib.request.Request('http://127.0.0.1:8866/agent/command',data=json.dumps({'projectRoot':str(root),'mode':'lua','code':code,'timeoutSeconds':30}).encode(),headers={'Content-Type':'application/json'})
 result=json.load(op.open(req,timeout=40));assert result['success'],result
 deadline=time.monotonic()+45
 while not (root/'runtime-result.json').exists() and time.monotonic()<deadline:time.sleep(.2)
 assert (root/'runtime-result.json').exists(),'Native replay timed out'
 final=json.loads((root/'runtime-result.json').read_text());assert final['success'],final
 print('PASS: native Lua, task670 real responses, actual ordinary MemoryCompressor, duplicate executed once, compaction once, ineffective recovery stopped, explicit continue succeeded, same-task different action succeeded.')
finally:
 shutil.rmtree(root)
