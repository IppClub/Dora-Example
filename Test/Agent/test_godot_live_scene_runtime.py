"""Registered execute_command live inspection: no provider, telemetry or new tool."""
import argparse,json,pathlib,sys,tempfile,time,urllib.request
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[1]/'support'))
from native_agent import NativeAgent,add_engine_argument
from godot_paths import ENGINE_ROOT
p=argparse.ArgumentParser(description=__doc__);add_engine_argument(p);p.add_argument('--library',type=pathlib.Path,required=True);p.add_argument('--output',type=pathlib.Path,required=True);a=p.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=True)
op=urllib.request.build_opener(urllib.request.ProxyHandler({}))
with tempfile.TemporaryDirectory(prefix='dora-live-scene-agent-') as temporary:
 project=pathlib.Path(temporary);(project/'project.godot').write_text('config_version=5\n[application]\nrun/main_scene="res://main.tscn"\n')
 (project/'main.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://main.gd" id="1"]\n[node name="Main" type="Node2D"]\nposition=Vector2(12,24)\nscript=ExtResource("1")\n')
 (project/'main.gd').write_text('extends Node2D\nvar hp := 3\nvar won := false\nvar trap: int:\n\tget:\n\t\tFileAccess.open("res://GETTER_EXECUTED",FileAccess.WRITE).store_string("bad")\n\t\treturn 1\n')
 service=NativeAgent(a.engine,ENGINE_ROOT);service.environment['DORA_GODOT_LIBRARY']=str(a.library.resolve())
 with service as engine:
  try:
   for name in ('GodotRuntimeScene','CommandTypes','Command','Types','Validation','Registry','Handlers'):
    req=urllib.request.Request('http://127.0.0.1:8866/ts/build',data=json.dumps({'path':str(ENGINE_ROOT/f'Assets/Script/Lib/Agent/Tool/{name}.ts'),'projectRoot':str(ENGINE_ROOT/'Assets/Script/Lib')}).encode(),headers={'Content-Type':'application/json','Origin':'http://127.0.0.1:8866'})
    result=json.load(op.open(req,timeout=90));assert result['success'],result
   code='''local D=require("Dora");local U=require("Agent.Utils")
D.Director.systemScheduler:schedule(D.once(function()
 local node
 local ok,err=pcall(function()
  for _,name in ipairs({"Agent.Tool.Command","Agent.Tool.GodotRuntimeScene","Agent.Tool.Registry","Agent.Tool.Validation","Agent.Tool.Handlers","Agent.Tools","Agent.Tool.Executor"})do package.loaded[name]=nil end
  local E=require("Agent.Tool.Executor");local R=require("Agent.Tool.Registry")
  local context={taskId=0,step=1,workingDir=projectDir,role="main",workMode="code",disabledAgentTools={},workflow={},services={},cancellation={isCancelled=function()return false end},emitProgress=function()end}
  local function await(p)local done,result,failure=false;p:addCallbacks(function(_,r)result=r;done=true end,function(_,e)failure=e;done=true end);while not done do D.sleep()end;assert(not failure,tostring(failure));return result end
  local function run(code)return await(E.executeRegisteredAgentTool({tool="execute_command",input={mode="lua",code=code,timeoutSeconds=30},context=context,schemaContext={searchDoraDocLimitMax=20}}))end
  for _,definition in ipairs(R.AGENT_TOOL_DEFINITIONS)do assert(not string.find(definition.name,"godot",1,true),definition.name)end
  local stopped=run([[inspectGodotRuntimeScene()]])
  assert(not stopped.output.success and stopped.output.godotRuntimeScenes and not stopped.output.godotRuntimeScenes[1].success,U.safeJsonEncode(stopped))
  node=D.GodotNode(projectDir,"",64,64);assert(node);node:addTo(D.Director.entry)
  local deadline=D.App.elapsedTime+20
  while not node.running do assert(node.lastError=="",node.lastError);assert(D.App.elapsedTime<deadline,"Godot startup timed out");D.sleep()end
  local live=run([[local r=inspectGodotRuntimeScene({nodePath="Main",properties={"position","script:hp","script:won","script:trap"}});assert(r.success)]])
  assert(live.execution.status=="DONE" and live.output.success,U.safeJsonEncode(live))
  local report=live.output.godotRuntimeScenes[1];local v=report.nodes[1].properties
  assert(v.position.value[1]==12 and v.position.value[2]==24 and v["script:hp"].value==3 and v["script:won"].value==false and v["script:trap"].unavailable,U.safeJsonEncode(report))
  assert(not context.workflow.unbuiltEdits and not context.workflow.editsSinceBuild,U.safeJsonEncode(context.workflow))
  assert(node.running and node.lastError=="" and not D.Content:exist(projectDir.."/GETTER_EXECUTED"))
  for _,code in ipairs({[[inspectGodotRuntimeScene({project=".."})]],[[inspectGodotRuntimeScene({nodePath="../"})]],[[inspectGodotRuntimeScene({properties={"script:hp+1"}})]],[[inspectGodotRuntimeScene({maxNodes=257})]],[[inspectGodotRuntimeScene({properties="hp"})]],[[inspectGodotRuntimeScene({unknown=true})]]})do
   local r=run(code);assert(not r.output.success and r.output.godotRuntimeScenes and not r.output.godotRuntimeScenes[1].success,U.safeJsonEncode(r))
  end
  rawset(_G,"_studio_agent_tool_begin",function()error("Unexpected Studio transport")end)
  local studio=run([[inspectGodotRuntimeScene()]])
  rawset(_G,"_studio_agent_tool_begin",nil)
  assert(not studio.output.success and string.find(studio.output.godotRuntimeScenes[1].message,"Studio",1,true),U.safeJsonEncode(studio))
  local done=false;node:unloadAsync(function(success,message)assert(success,message);done=true end);while not done do D.sleep()end;node=nil
  local unloaded=run([[inspectGodotRuntimeScene()]])
  assert(not unloaded.output.success and not unloaded.output.godotRuntimeScenes[1].success,U.safeJsonEncode(unloaded))
  D.Content:save(projectDir.."/tool-results.json",U.safeJsonEncode({stopped=stopped,live=live,studio=studio,unloaded=unloaded}))
 end)
 if node then node:unloadAsync(function()end)end
 D.Content:save(projectDir.."/result.json",U.safeJsonEncode({success=ok,message=tostring(err)}))
end));print("LIVE_SCENE_TOOL_STARTED")'''
   engine.command(project,code,timeout_seconds=60)
   deadline=time.monotonic()+90
   while not (project/'result.json').exists() and time.monotonic()<deadline:time.sleep(.1)
   result=json.loads((project/'result.json').read_text());assert result['success'],result
   (out/'result.json').write_text(json.dumps(result,indent=2));(out/'tool-results.json').write_bytes((project/'tool-results.json').read_bytes())
   print('PASS: registered execute_command live snapshots, failure propagation, getter exclusion, read-only workflow, unload and Studio rejection')
  finally:(out/'engine.log').write_text(engine.log_path.read_text(errors='replace'))
