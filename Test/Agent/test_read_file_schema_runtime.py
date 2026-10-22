"""Native model schema/executor regression; --ornith adds an actual provider call."""
import json, pathlib, tempfile, urllib.request, time, shutil, sys
root = pathlib.Path(tempfile.mkdtemp(prefix='dora-read-schema-'))
(root/'init.ts').write_text('const marker = "READ_SCHEMA_OK";\n')
code = r'''
local H=require("Script.Dev.AgentHost");local release=H.acquire()
local D=require("Dora");local U=require("Agent.Utils")
local R=require("Agent.Tool.Registry");local E=require("Agent.Tool.Executor");local J=require("Agent.Tool.JsonSchema")
D.thread(function()
 local ok,err=pcall(function()
  local function await(p)
   local done,result=false,nil
   p["then"](p,function(_,r) result=r;done=true end)
   while not done do sleep() end
   return result
  end
  local function noAnyOf(value)
   if type(value)~="table" then return end
   assert(value.anyOf==nil,"model schema contains anyOf")
   for _,v in pairs(value) do noAnyOf(v) end
  end
  for _,role in ipairs({"main","sub"}) do
   for _,mode in ipairs({"code","plan"}) do
    noAnyOf(R.buildDecisionToolSchema(role,20,{workMode=mode}))
   end
  end
  noAnyOf(R.buildDecisionToolSchemaForTools(R.AGENT_TOOL_DEFINITIONS,{searchDoraDocLimitMax=20}))
  for _,definition in ipairs(R.AGENT_TOOL_DEFINITIONS) do noAnyOf(definition.inputSchema(nil,{searchDoraDocLimitMax=20})) end
  local tool=R.buildDecisionToolSchemaForTools({R.getToolDefinition("read_file")},{searchDoraDocLimitMax=20})[1]
  local schema=tool["function"].parameters
  assert(schema.anyOf==nil and #schema.required==1 and schema.required[1]=="reads")
  assert(schema.properties.path==nil and schema.properties.reads.minItems==1)
  local validator=J.compileJsonSchema(schema);assert(validator.success)
  for _,input in ipairs({{}, {path="init.ts"}, {reads={}}, {reads={{startLine=1}}}}) do
   assert(not validator.validator:validate(input).valid,"model schema accepted invalid input")
  end
  assert(validator.validator:validate({reads={{path="init.ts"}}}).valid)
  local context={workingDir=projectDir,role="main",workMode="code",disabledAgentTools={},workflow={},useChineseResponse=false,cancellation={stopToken={stopped=false},isCancelled=function() return false end,reason=function() end},services={}}
  local function execute(input)
   return await(E.executeRegisteredAgentTool({tool="read_file",input=input,context=context,schemaContext={searchDoraDocLimitMax=20}}))
  end
  for _,input in ipairs({{path="init.ts",startLine=1,endLine=1},{reads={{path="init.ts",startLine=1,endLine=1}}},{path="init.ts",reads={{path="init.ts"}}}}) do
   local r=execute(input)
   assert(r.execution.status=="DONE" and r.output.success,U.safeJsonEncode(r))
   local row=r.output.results and r.output.results[1] or r.output
   assert(row.content:find("READ_SCHEMA_OK",1,true))
  end
  for _,input in ipairs({{}, {reads={}}, {path=""}, {reads={{path=""}}}}) do assert(execute(input).execution.status=="FAILED") end
  if ORNITH then
   local config=U.getLLMConfig(21);assert(config.success and config.config.model=="ornith-1.5-35b")
   local r=await(U.callLLM({{role="user",content="Call read_file to read init.ts lines 1 through 1. Use the provided tool."}},{tools={tool},tool_choice={type="function",["function"]={name="read_file"}},temperature=0,max_tokens=4096},config.config))
   assert(r.success,"Ornith request failed")
   local call=r.response.choices[1].message.tool_calls[1]
   assert(call["function"].name=="read_file")
   local input=assert(U.safeJsonDecode(call["function"].arguments))
   assert(validator.validator:validate(input).valid,"Ornith generated invalid reads arguments")
   assert(input.reads[1].path=="init.ts","Ornith chose wrong file")
   local execution=execute(input)
   assert(execution.execution.status=="DONE" and execution.output.success,"Ornith call failed execution")
   assert(execution.output.results[1].content:find("READ_SCHEMA_OK",1,true))
  end
 end)
 D.Content:save(projectDir.."/result.json",U.safeJsonEncode({success=ok,message=tostring(err)}));release()
end)
print("READ_FILE_SCHEMA_STARTED")
'''.replace('ORNITH', 'true' if '--ornith' in sys.argv else 'false')
op=urllib.request.build_opener(urllib.request.ProxyHandler({}))
try:
 r=json.load(op.open(urllib.request.Request('http://127.0.0.1:8866/agent/command',data=json.dumps({'projectRoot':str(root),'mode':'lua','code':code,'timeoutSeconds':30}).encode(),headers={'Content-Type':'application/json'}),timeout=35))
 assert r['success'],r
 deadline=time.monotonic()+180
 while not (root/'result.json').exists() and time.monotonic()<deadline: time.sleep(.2)
 result=json.loads((root/'result.json').read_text());assert result['success'],result
 print('PASS: required reads model schema; legacy path and reads actual execution; invalid inputs rejected'+('; actual Ornith arguments and file read' if '--ornith' in sys.argv else ''))
finally: shutil.rmtree(root)
