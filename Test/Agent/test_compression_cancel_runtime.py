"""Opt-in native HTTP cancellation and ordinary compression budget regression."""
import json, pathlib, tempfile, urllib.request, shutil, time, threading, os
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler
requests = []
class Provider(BaseHTTPRequestHandler):
    def log_message(self, *args): pass
    def do_POST(self):
        body=json.loads(self.rfile.read(int(self.headers['Content-Length'])))
        requests.append((self.path,body))
        if self.path.startswith('/cancel'): time.sleep(3)
        message={'role':'assistant','tool_calls':[{'id':'memory','type':'function','function':{'name':'save_memory','arguments':json.dumps({'history_entry':'Inspected fixture; continue existing game.','memory_update':'# Memory\nFixture verified.','session_summary_update':'# Summary\nContinue game.'})}}]}
        length=self.path.startswith('/exhaust')
        if self.path == '/xml': message={'role':'assistant','content':'<memory_update_result><history_entry>Fixture verified.</history_entry><memory_update>Fixture verified.</memory_update></memory_update_result>'}
        response={'choices':[{'finish_reason':'length' if length else 'tool_calls','message':{'role':'assistant','content':'','reasoning_content':'Thinking'} if length else message}]}
        raw=json.dumps(response).encode()
        if body.get('stream'):
            chunk={'id':'fixture','object':'chat.completion.chunk','choices':[{'index':0,'delta':{'role':'assistant','content':'Fixture verified.'},'finish_reason':'stop'}]}
            raw=('data: '+json.dumps(chunk)+'\n\ndata: [DONE]\n\n').encode()
        try:
            self.send_response(200);self.send_header('Content-Type','text/event-stream' if body.get('stream') else 'application/json');self.send_header('Content-Length',str(len(raw)));self.end_headers();self.wfile.write(raw)
        except (BrokenPipeError,ConnectionResetError): pass
server=ThreadingHTTPServer(('127.0.0.1',0),Provider)
threading.Thread(target=server.serve_forever,daemon=True).start()
root=pathlib.Path(tempfile.mkdtemp(prefix='dora-compression-cancel-'))
(root/'init.lua').write_text('return true\n')
code=r'''
local H=require("Script.Dev.AgentHost")
local release=H.acquire()
local U=require("Agent.Utils")
local D=require("Dora")
local l=require("lualib_bundle")
-- Isolate the compiled module under test; never replace a live task's module cache.
local M=assert(loadfile("ENGINE_ROOT/Assets/Script/Lib/Agent/Runtime/Memory.lua"))()
local presets=assert(loadfile("ENGINE_ROOT/Assets/Script/Dev/Mobile/LLMSetup.lua"))().mobileLLMPresets
for _,preset in ipairs(presets) do
 local options=assert(U.safeJsonDecode(preset.customOptions)).auxiliaryOptions
 assert(preset.maxTokens==64000,"mobile default budget differs: "..preset.id)
 assert(options.max_tokens==nil and options.max_completion_tokens==nil,"mobile auxiliary budget remains: "..preset.id)
end
D.thread(function()
 local ok,err=pcall(function()
  local messages={{role="user",content="Continue existing game; inspect fixture."},{role="assistant",content="Inspected fixture."}}
  local function run(path,scope,cancel,mode,budget)
   local token={stopped=false}
   budget=budget or 64000
   local options={max_tokens=budget,reasoning_effort="high"}
   local custom={reasoning_effort="high",auxiliaryOptions={max_tokens=2048,max_completion_tokens=1024,reasoning_effort="low",thinking={type="disabled"}}}
   custom.top_p=0.95;custom.tool_choice="required"
   custom.auxiliaryOptions.top_p=require("json").null
   if path=="override" then custom.max_tokens=64000 end
   if path=="default-effort" then custom.auxiliaryOptions={max_tokens=1024} end
   if path=="completion" then custom.max_tokens=require("json").null;custom.max_completion_tokens=budget end
   if path=="null-effort" then custom.auxiliaryOptions.reasoning_effort=require("json").null end
   local config={url="http://127.0.0.1:PORT/"..path,apiKey="test-only",model="test",contextWindow=1000000,maxTokens=budget,customOptions=custom}
   -- Compare with a normal LLM request using exactly the same configuration.
   if not cancel and not path:find("exhaust",1,true) then
    local main=nil
    local mainConfig={}
    for key,value in pairs(config) do mainConfig[key]=value end
    mainConfig.url="http://127.0.0.1:PORT/main-"..path
    local promise=U.callLLMStreamAggregated(messages,options,nil,mainConfig)
    promise["then"](promise,function(_,r) main=r end)
    while not main do sleep() end
    assert(main.success,U.safeJsonEncode(main))
   end
   local compressor=l.__TS__New(M.MemoryCompressor,{projectDir=projectDir,scope=scope,compressionTargetThreshold=0.5,maxCompressionRounds=3,llmConfig=config})
   local storage=compressor:getStorage()
   local before=storage:readMemory()
   local result=nil
   local start=D.App.runningTime
   if cancel then D.thread(function() sleep(0.2); token.stopped=true;token.reason="test cancellation" end) end
   local promise=compressor:compress(messages,options,5,mode or "tool_calling",{stopToken=token})
   promise["then"](promise,function(_,r) result=r end)
   while not result do sleep() end
   if cancel then
    assert(D.App.runningTime-start<1,"HTTP cancellation waited for provider")
    assert(not result.success and result.compressedCount==0 and not result.fallbackArchived,U.safeJsonEncode(result))
    assert(storage:readMemory()==before,"cancelled request wrote memory")
   elseif path:find("exhaust",1,true) then assert(result.fallbackArchived and result.error:find("configured output budget",1,true),U.safeJsonEncode(result))
   else assert(result.success and not result.fallbackArchived and storage:readMemory():find("Fixture verified",1,true),U.safeJsonEncode(result)) end
   return D.App.runningTime-start
  end
  local seconds=run("cancel","cancel",true)
  run("cancel-xml","cancel-xml",true,"xml")
  run("small","small",false,nil,2048)
  run("large","large",false,nil,131072)
  run("xml","xml",false,"xml")
  run("null-effort","null-effort",false)
  run("exhaust","exhaust",false)
  run("exhaust-xml","exhaust-xml",false,"xml")
  run("override","override",false,nil,2048)
  run("default-effort","default-effort",false)
  run("completion","completion",false)
  D.Content:save(projectDir.."/result.json",U.safeJsonEncode({success=true,cancelSeconds=seconds}))
 end)
 if not ok then D.Content:save(projectDir.."/result.json",U.safeJsonEncode({success=false,message=tostring(err)})) end
 release()
end)
print("COMPRESSION_NATIVE_STARTED")
'''.replace('PORT',str(server.server_port)).replace('ENGINE_ROOT',os.environ.get('DORA_ENGINE_ROOT','/Users/Jin/Workspace/Dora-SSR'))
op=urllib.request.build_opener(urllib.request.ProxyHandler({}))
try:
    r=json.load(op.open(urllib.request.Request('http://127.0.0.1:8866/agent/command',data=json.dumps({'projectRoot':str(root),'mode':'lua','code':code,'timeoutSeconds':30}).encode(),headers={'Content-Type':'application/json'}),timeout=35))
    assert r['success'],r
    deadline=time.monotonic()+20
    while not (root/'result.json').exists() and time.monotonic()<deadline: time.sleep(.1)
    result=json.loads((root/'result.json').read_text());assert result['success'],result
    assert sum(p=='/cancel' for p,b in requests)==1 and sum(p=='/cancel-xml' for p,b in requests)==1,requests
    assert [b['max_tokens'] for p,b in requests if p=='/exhaust']==[64000],requests
    assert [b['max_tokens'] for p,b in requests if p=='/exhaust-xml']==[64000],requests
    for path,budget in [('override',64000),('default-effort',64000),('small',2048),('large',131072),('xml',64000),('null-effort',64000),('completion',64000)]:
        main=[b for p,b in requests if p=='/main-'+path]
        compressed=[b for p,b in requests if p=='/'+path]
        assert len(main)==len(compressed)==1,(path,requests)
        for field in ['max_tokens','max_completion_tokens']:
            assert main[0].get(field)==compressed[0].get(field),(path,field,requests)
        field='max_completion_tokens' if path=='completion' else 'max_tokens'
        assert compressed[0][field]==budget,(path,requests)
        assert main[0]['reasoning_effort']=='high',main
        assert compressed[0].get('reasoning_effort')==(None if path=='null-effort' else 'minimal' if path=='default-effort' else 'low'),compressed
        assert main[0]['tool_choice']=='required',main
        assert main[0]['top_p']==0.95,main
        if path!='xml': assert 'tool_choice' not in compressed[0],compressed
        if path!='default-effort':
            assert compressed[0]['thinking']=={'type':'disabled'},compressed
            assert 'top_p' not in compressed[0],compressed
        else: assert compressed[0]['top_p']==0.95,compressed
    assert all(b['max_tokens']==64000 and b['reasoning_effort']=='low' for p,b in requests if p.startswith('/cancel')),requests
    assert all(not p.read_text().strip() for p in (root/'.agent/cancel').glob('*HISTORY*')),'cancellation archived history'
    print('PASS: shared main/compression budgets 2048, 64000, 131072; legacy auxiliary budgets ignored; max_completion_tokens preserved; independent reasoning/null removal; tool/XML; truncation does not grow budget; cancellation %.3fs.'%result['cancelSeconds'])
finally:
    server.shutdown();shutil.rmtree(root)
