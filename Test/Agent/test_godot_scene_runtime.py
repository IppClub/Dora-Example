"""Actual execute_command scene injection, with an unchanged Agent tool set."""
import argparse,json,pathlib,sys,tempfile,time,urllib.request
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[1]/'support'))
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[1]/'Godot/tests/services'))
from native_agent import NativeAgent,add_engine_argument
from godot_paths import ENGINE_ROOT
from scene_fixture import make_fixture
p=argparse.ArgumentParser(description=__doc__);add_engine_argument(p);p.add_argument('--output',type=pathlib.Path,required=True);a=p.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=True)
op=urllib.request.build_opener(urllib.request.ProxyHandler({}))
with tempfile.TemporaryDirectory(prefix='dora-agent-scene-') as temporary:
 project=pathlib.Path(temporary);make_fixture(project)
 with NativeAgent(a.engine,ENGINE_ROOT) as engine:
  try:
   for name in ('GodotScene','CommandTypes','Command','Registry'):
    data={'path':str(ENGINE_ROOT/f'Assets/Script/Lib/Agent/Tool/{name}.ts'),'projectRoot':str(ENGINE_ROOT/'Assets/Script/Lib')}
    req=urllib.request.Request('http://127.0.0.1:8866/ts/build',data=json.dumps(data).encode(),headers={'Content-Type':'application/json','Origin':'http://127.0.0.1:8866'})
    result=json.load(op.open(req,timeout=90));assert result['success'],result
   code='''local D=require("Dora");local U=require("Agent.Utils")
D.Director.systemScheduler:schedule(D.once(function()
 local ok,err=pcall(function()
  for _,name in ipairs({"Agent.Tool.Command","Agent.Tool.GodotScene","Agent.Tool.Registry","Agent.Tool.Handlers","Agent.Tools","Agent.Tool.Executor"})do package.loaded[name]=nil end
  local E=require("Agent.Tool.Executor");local R=require("Agent.Tool.Registry")
  local context={taskId=0,step=1,workingDir=projectDir,role="main",workMode="code",disabledAgentTools={},workflow={},services={},cancellation={isCancelled=function()return false end},emitProgress=function()end}
  local function await(p)local done,result,failure=false;p:addCallbacks(function(_,r)result=r;done=true end,function(_,e)failure=e;done=true end);while not done do D.sleep()end;assert(not failure,tostring(failure));return result end
  local function run(code)return await(E.executeRegisteredAgentTool({tool="execute_command",input={mode="lua",code=code,timeoutSeconds=60},context=context,schemaContext={searchDoraDocLimitMax=20}}))end
  for _,definition in ipairs(R.AGENT_TOOL_DEFINITIONS)do assert(not string.find(definition.name,"godot",1,true),definition.name)end
  local full=run([[local scene=inspectGodotScene({path="main.tscn"});assert(scene.success and scene.nodeCount==3)]])
  assert(full.output.success,U.safeJsonEncode(full));local scene=full.output.godotScenes[1]
  assert(scene.path=="main.tscn" and scene.nodeCount==3 and #scene.resources==4 and #scene.connections==1,U.safeJsonEncode(scene))
  assert(scene.nodes[1].script.path=="res://danger.gd")
  assert(not context.workflow.unbuiltEdits and not context.workflow.hasBuilt)
  local empty=run([[inspectGodotScene({path="running/main.tscn"})]])
  assert(empty.output.success and empty.output.godotScenes[1].nodeCount==1 and #empty.output.godotScenes[1].resources==0,U.safeJsonEncode(empty))
  local filtered=run([[inspectGodotScene({path="main.tscn",nodePath="Player"})]])
  assert(filtered.output.success and #filtered.output.godotScenes[1].nodes==1,U.safeJsonEncode(filtered))
  local limited=run([[inspectGodotScene({path="main.tscn",maxNodes=1,maxProperties=1})]])
  assert(limited.output.success and limited.output.godotScenes[1].truncated)
  for _,code in ipairs({[[inspectGodotScene({path="../escape.tscn"})]],[[inspectGodotScene({path="escape.tscn"})]],[[inspectGodotScene({path="object.tscn"})]],[[inspectGodotScene({path="bad.tscn"})]],[[inspectGodotScene({path="binary.scn"})]],[[inspectGodotScene({path="main.tscn",maxNodes=0})]],[[inspectGodotScene({path="main.tscn",maxNodes="bad"})]],[[inspectGodotScene()]]})do
   local r=run(code);assert(not r.output.success and not r.output.godotScenes[1].success,U.safeJsonEncode(r))
  end
  rawset(_G,"_studio_agent_tool_begin",function()error("Unexpected Studio Player transport")end)
  local studio=run([[inspectGodotScene({path="main.tscn"})]])
  rawset(_G,"_studio_agent_tool_begin",nil)
  assert(not studio.output.success and string.find(studio.output.godotScenes[1].message,"Studio",1,true),U.safeJsonEncode(studio))
  D.Content:save(projectDir.."/reports.json",U.safeJsonEncode({full=full,filtered=filtered,limited=limited,studio=studio}))
 end)
 D.Content:save(projectDir.."/result.json",U.safeJsonEncode({success=ok,message=tostring(err)}))
end));print("SCENE_INSPECT_STARTED")'''
   engine.command(project,code,timeout_seconds=60)
   deadline=time.monotonic()+90
   while not (project/'result.json').exists() and time.monotonic()<deadline:time.sleep(.1)
   result=json.loads((project/'result.json').read_text());assert result['success'],result
   (out/'result.json').write_text(json.dumps(result,indent=2));(out/'reports.json').write_bytes((project/'reports.json').read_bytes())
   assert not (project/'.godot').exists()
   for name in ('SCRIPT_EXECUTED','RESOURCE_EXECUTED','AUTOLOAD_EXECUTED'):assert not (project/name).exists(),name
   print('PASS: native TS compiler and execute_command injection, typed scene metadata, automatic failure reporting, subtree/limits/path guards, no script/cache writes, unchanged tool registry and Studio rejection')
  finally:(out/'engine.log').write_text(engine.log_path.read_text(errors='replace'))
