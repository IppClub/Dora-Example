"""Real native Godot Agent preview: cold start, failures, partial captures and recovery.

Run with --engine /path/to/Dora --library /path/to/libdora_godot.dylib.
This owns a disposable native service and requires an available GPU/display.
"""
import argparse,json,time,tempfile,pathlib,sys
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[1]/'support'))
from native_agent import NativeAgent, add_engine_argument
from godot_paths import ENGINE_ROOT
parser=argparse.ArgumentParser(description=__doc__)
add_engine_argument(parser)
parser.add_argument('--library',type=pathlib.Path,required=True)
parser.add_argument('--output',type=pathlib.Path,required=True)
args=parser.parse_args()
root=ENGINE_ROOT;out=args.output.resolve();out.mkdir(parents=True,exist_ok=True)
engine=NativeAgent(args.engine,root)
engine.environment['DORA_GODOT_LIBRARY']=str(args.library.resolve())
with tempfile.TemporaryDirectory(prefix='dora-godot-preview-') as temporary, engine:
 projects=[]
 for kind in ['normal','startup-error','runtime-error','recovery']:
  project=pathlib.Path(temporary)/kind;project.mkdir();projects.append(project)
  (project/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Dora preview regression"\nrun/main_scene="res://'+('absent.tscn' if kind=='startup-error' else 'main.tscn')+'"\n[display]\nwindow/size/viewport_width=640\nwindow/size/viewport_height=360\n[rendering]\nrenderer/rendering_method="mobile"\n')
  (project/'main.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://main.gd" id="1"]\n[node name="Main" type="Node2D"]\nscript=ExtResource("1")\n')
  script='extends Node2D\nfunc _draw():\n\tdraw_rect(Rect2(0,0,640,360),Color(0.2,0.8,0.3))\n'
  if kind=='runtime-error':script+='var elapsed := 0.0\nfunc _process(delta):\n\telapsed += delta\n\tif elapsed > 0.6:\n\t\tget_node("PreviewMissingNode")\n'
  (project/'main.gd').write_text(script)
  (project/'init.lua').write_text('local D=require("Dora");local game=assert(D.GodotNode('+json.dumps(str(project))+',"",640,360,3));game:addTo(D.Director.ui)\n')
  resultfile=project/'result.json'
  code='''local D=require("Dora")
D.Director.systemScheduler:schedule(D.once(function()
 local result
 local Tools=require("Agent.Tools")
 local code='''+json.dumps('local r=previewGame({entry="init.lua",captureAtSeconds={0,2}}); print("PREVIEW_RESULT",r.success,r.message)')+'''
 local promise=Tools.executeCommand({workDir=projectDir,mode="lua",code=code,timeoutSeconds=50})
 promise:addCallbacks(function(_,value) result=value end,function(_,e) result={success=false,message=tostring(e)} end)
 while not result do sleep() end
 D.Content:save(projectDir.."/result.json",require("Agent.Utils").safeJsonEncode(result))
end))
print("Preview regression started")'''
  engine.command(project,code)
  deadline=time.monotonic()+65
  while not resultfile.exists() and time.monotonic()<deadline:time.sleep(.1)
  result=json.loads(resultfile.read_text());(out/(kind+'.json')).write_text(json.dumps(result,indent=2))
  print(kind,'success='+str(result['success']),flush=True)
  assert result['success']==(kind in ('normal','recovery')),result
  if kind in ('normal','recovery'):
   assert result['previewGame']['frameCount']==2,result
   for file in result['previewGame']['files']:
    from PIL import Image
    image=Image.open(project/file).convert('RGB');pixels=image.get_flattened_data() if hasattr(image,'get_flattened_data') else image.getdata();green=sum(g>r*1.8 and g>b*1.5 and g>120 for r,g,b in pixels)
    assert green>1000,(image.size,green)
    (out/(kind+'-'+pathlib.Path(file).name)).write_bytes((project/file).read_bytes())
  elif kind=='startup-error':assert not result['previewGame'].get('files'),result
  else:
   assert 'PreviewMissingNode' in result['message'],result
   assert len(result['previewGame']['files'])==1,result
 (out/'verification.json').write_text(json.dumps({'passed':True,'cases':['cold-start','startup-failure','runtime-error-partial-capture','clean-recovery'],'scope':'Reported runtime errors only; optimized release builds can omit some GDScript checks.'},indent=2)+'\n')
 print('PASS: cold startup screenshot, startup failure, runtime failure with partial capture, and clean recovery',flush=True)
