"""Verify Godot -> Dora -> the Web IDE log endpoint in a disposable native host."""
import argparse,json,pathlib,subprocess,sys,tempfile,time
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[1]/'support'))
from native_agent import NativeAgent,add_engine_argument
from godot_paths import ENGINE_ROOT
p=argparse.ArgumentParser(description=__doc__);add_engine_argument(p)
p.add_argument('--library',type=pathlib.Path,required=True);p.add_argument('--output',type=pathlib.Path,required=True);a=p.parse_args()
out=a.output.resolve();out.mkdir(parents=True,exist_ok=True)
engine=NativeAgent(a.engine,ENGINE_ROOT);engine.environment['DORA_GODOT_LIBRARY']=str(a.library.resolve())
with tempfile.TemporaryDirectory(prefix='dora-native-godot-logs-') as temp,engine:
 project=pathlib.Path(temp)
 (project/'project.godot').write_text('config_version=5\n[application]\nrun/main_scene="res://main.tscn"\n[rendering]\nrenderer/rendering_method="mobile"\n')
 (project/'main.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://main.gd" id="1"]\n[node name="Main" type="Node2D"]\nscript=ExtResource("1")\n')
 (project/'main.gd').write_text('extends Node2D\nfunc _ready():\n\tpush_warning("DORA_LOG_WARNING_中文")\n\tprinterr("DORA_LOG_STDERR_中文")\n\tpush_error("DORA_LOG_ERROR_中文")\nfunc _exit_tree():\n\tprinterr("DORA_LOG_EXIT_中文")\n')
 (project/'init.lua').write_text('local D=require("Dora");local game=assert(D.GodotNode('+json.dumps(str(project))+',"",64,64,2));game:addTo(D.Director.ui)\n')
 engine.command(project,'local ok,msg=enterEntryAsync({fileName="init.lua"});assert(ok,msg);sleep(1);print("Log fixture observed")')
 deadline=time.monotonic()+15
 while time.monotonic()<deadline:
  raw=engine.log_path.read_text()
  if '[Godot] DORA_LOG_EXIT_中文' in raw:break
  time.sleep(.1)
 else:raise AssertionError(raw[-8000:])
 result=subprocess.run([str(a.engine.resolve()),'--asset',str(ENGINE_ROOT/'Assets'),'cli','agent','log','-n','1000'],env=engine.environment,text=True,capture_output=True,timeout=20)
 (out/'endpoint-response.txt').write_text(result.stdout+result.stderr)
 assert result.returncode==0,(result.returncode,result.stdout,result.stderr)
 response=json.loads(result.stdout);assert response['success'],response
 log=response['log']
 for token,level in [('WARNING','warning'),('STDERR','error'),('ERROR','error'),('EXIT','error')]:
  lines=[line for line in log.splitlines() if '[Godot]' in line and 'DORA_LOG_'+token+'_中文' in line]
  assert len(lines)==1,(token,lines,log)
  assert '['+level+']' in lines[0],lines[0]
 assert not any('GodotNode:' in line and 'DORA_LOG_ERROR_' in line for line in log.splitlines()),log
 (out/'engine.log').write_text(raw);(out/'dora-log.txt').write_text(log)
 (out/'verification.json').write_text(json.dumps({'passed':True,'scope':'Native Godot errors/warnings/stderr and teardown -> Dora log API, Unicode, severity and duplicate suppression; no full backtrace claim'},indent=2)+'\n')
 print('PASS: real embedded Godot errors/warnings/stderr/teardown reach Dora Web IDE log API with Unicode, severity and no duplicate session error')
