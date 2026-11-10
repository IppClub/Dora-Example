"""Registered Agent Godot docs search/read/grep in a disposable native host.

--assets can point at a built app's Resources to verify offline package use.
"""
import argparse,sys,pathlib,tempfile,json,time
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[1]/'support'))
from native_agent import NativeAgent,add_engine_argument
from godot_paths import ENGINE_ROOT
parser=argparse.ArgumentParser(description=__doc__);add_engine_argument(parser)
parser.add_argument('--assets',type=pathlib.Path,default=ENGINE_ROOT/'Assets')
parser.add_argument('--output',type=pathlib.Path,required=True)
args=parser.parse_args();root=ENGINE_ROOT;out=args.output.resolve();out.mkdir(parents=True,exist_ok=True)
with tempfile.TemporaryDirectory(prefix='dora-api-docs-') as project, tempfile.TemporaryDirectory(prefix='dora-doc-assets-') as checkout:
 (pathlib.Path(checkout)/'Assets').symlink_to(args.assets.resolve(),target_is_directory=True)
 with NativeAgent(args.engine,checkout) as engine:
  code='''local D=require("Dora")
 D.Director.systemScheduler:schedule(D.once(function()
  local ok,err=pcall(function()
  local names={"Agent.Tool.Workspace","Agent.Tool.DoraDocSearch","Agent.Tool.Handlers","Agent.Tool.Registry","Agent.Tool.Validation","Agent.Tool.Executor","Agent.Tools"}
  for _,name in ipairs(names) do package.loaded[name]=nil end
  local E=require("Agent.Tool.Executor")
  local context={taskId=0,step=1,workingDir=projectDir,role="main",workMode="code",useChineseResponse=true,disabledAgentTools={},workflow={},services={},cancellation={isCancelled=function()return false end},emitProgress=function()end}
  local function await(p)
   local done,result,failed=false
   p:addCallbacks(function(_,r)result=r;done=true end,function(_,e)failed=tostring(e);done=true end)
   while not done do D.sleep()end
   assert(not failed,failed);return result
  end
  local function run(tool,input)
   local r=await(E.executeRegisteredAgentTool({tool=tool,input=input,context=context,schemaContext={searchDoraDocLimitMax=20}}))
   assert(r.execution.status=="DONE",require("Agent.Utils").safeJsonEncode(r));return r.output
  end
  local results={}
  for _,pattern in ipairs({"CharacterBody2D.move_and_slide","Node2D.get_node","Input.is_action_pressed","Node.ready","ResourceLoader.load","node2d.GET_NODE()","@GDScript","Dora","move_and_slide"}) do
   local r=run("search_dora_doc",{docType="godot-api",pattern=pattern,limit=5})
   assert(r.success and #r.results>0,require("Agent.Utils").safeJsonEncode(r))
   assert(r.docLanguage=="en" and r.programmingLanguage=="gdscript" and r.sourceVersion==expectedVersion)
   local hit=r.results[1]
   local read=run("read_file",{path=hit.file,startLine=hit.line,endLine=hit.line+15})
   assert(read.success,require("Agent.Utils").safeJsonEncode(read))
   local grep=run("grep_files",{path=hit.file,pattern="Godot",limit=2})
   assert(grep.success,require("Agent.Utils").safeJsonEncode(grep))
   results[pattern]=r
  end
  assert(results["move_and_slide"].results[1].file=="@dora-doc/godot-api/classes/CharacterBody2D.md", require("Agent.Utils").safeJsonEncode(results["move_and_slide"]))
  local inherited=results["Node2D.get_node"].results[1]
  assert(inherited.file=="@dora-doc/godot-api/classes/Node.md")
  local capped=run("search_dora_doc",{docType="godot-api",pattern="runtime",limit=1})
  assert(capped.success and capped.truncated and capped.totalResults>1 and #capped.results==1)
  for _,path in ipairs({"@dora-doc/godot-api/../en/welcome.md","@dora-doc/godot-api/classes/../../en/welcome.md","@dora-doc/godot-api/manifest.json"}) do
   assert(run("read_file",{path=path}).success==false)
  end
  local dora=run("search_dora_doc",{docType="dora-api",pattern="GodotNode",limit=3})
  assert(dora.success and #dora.results>0 and dora.docLanguage=="zh")
  D.Content:save(projectDir.."/queries.json",require("Agent.Utils").safeJsonEncode(results))
  end)
  D.Content:save(projectDir.."/result.json",require("Agent.Utils").safeJsonEncode({success=ok,message=tostring(err)}))
 end))
 print("Godot docs regression started")'''
  engine.command(project,"local expectedVersion="+json.dumps(json.loads((root/'Source/3rdParty/Godot/UPSTREAM.json').read_text())['version'])+"\n"+code)
  target=pathlib.Path(project)/'result.json';deadline=time.monotonic()+45
  while not target.exists() and time.monotonic()<deadline:time.sleep(.1)
  result=json.loads(target.read_text());print(result,flush=True);assert result['success'],result
  (out/'queries.json').write_bytes((pathlib.Path(project)/'queries.json').read_bytes())
  print('PASS: registered Godot doc search, inherited symbols, English fallback, read/grep, truncation, isolation and Dora compatibility',flush=True)
