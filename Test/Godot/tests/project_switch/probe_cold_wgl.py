#!/usr/bin/env python3
"""Focused cold-start WGL image diagnostic; does not claim lifecycle acceptance."""
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[4]/'Test/support'))
from godot_paths import ENGINE_ROOT,TEST_REPO
import argparse,json,os,subprocess
from PIL import Image
import project_delivery as delivery
from project import lua_string
p=argparse.ArgumentParser()
for k in ('binary','runtime-package','project','output'):p.add_argument('--'+k,type=Path,required=True)
p.add_argument('--direct',choices=['0','1'],required=True)
p.add_argument('--inspect-msaa',action='store_true')
a=p.parse_args();out=a.output;assert not out.exists();out.mkdir(parents=True)
with (out/'prepare.log').open('w') as log:
 subprocess.run([sys.executable,str(ENGINE_ROOT/'Tools/Godot/project.py'),'run',str(a.project),'--binary',str(a.binary),'--asset-source',str(ENGINE_ROOT/'Assets'),'--runtime-package',str(a.runtime_package),'--work-dir',str(out/'host'),'--no-run'],stdout=log,stderr=subprocess.STDOUT,check=True)
template=(TEST_REPO/'Test/Godot/tests/project_switch/real_player.lua').read_text()
scene=''
if a.inspect_msaa:
 script=out/'inspect.gd'
 script.write_text('''extends Node
var frames=0
func _process(_dt):
 frames+=1
 var v=get_viewport()
 if frames==20 or frames==80 or frames==140 or frames==200 or frames==260:
  print("DORA_MSAA_PROBE frame=",frames," msaa=",v.msaa_3d," disabled3d=",v.disable_3d," camera=",v.get_camera_3d()," objects=",v.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_OBJECTS_IN_FRAME))
 if frames==60:
  v.get_texture().get_image().save_png(OUTPUT+"/native-msaa.png")
  v.msaa_3d=Viewport.MSAA_DISABLED
 if frames==120:
  v.get_texture().get_image().save_png(OUTPUT+"/native-no-msaa.png")
  for node in get_tree().current_scene.find_children("*", "Light3D", true, false):
   node.shadow_enabled=false
 if frames==180:
  v.get_texture().get_image().save_png(OUTPUT+"/native-no-shadows.png")
  v.get_camera_3d().projection=Camera3D.PROJECTION_PERSPECTIVE
 if frames==240:
  v.get_texture().get_image().save_png(OUTPUT+"/native-perspective.png")
'''.replace('OUTPUT',json.dumps(str(out).replace('\\','/'))))
 scene=str(out/'inspect.tscn').replace('\\','/')
 Path(scene).write_text('[gd_scene load_steps=3 format=3]\n[ext_resource type="PackedScene" path="res://Main.tscn" id="1"]\n[ext_resource type="Script" path='+json.dumps(str(script).replace('\\','/'))+' id="2"]\n[node name="Main" instance=ExtResource("1")]\n[node name="DoraInspect" type="Node" parent="."]\nscript=ExtResource("2")\n')
items='{ {scene='+lua_string(scene)+',path='+lua_string(str(a.project))+',name="pck-squash",width=960,height=540,buffers=3} }'
startup=template.replace('@OUTPUT@',lua_string(str(out))).replace('@PROJECTS@',items).replace('@MIN_TICKS@','450' if a.inspect_msaa else '90').replace('@MINIMAL_EDGES@','false').replace('@INVALID@','""')
(out/'host/assets/Script/init.lua').write_text(startup)
m=json.loads((a.runtime_package/'manifest.json').read_text());env={k:v for k,v in os.environ.items() if not k.startswith(('DORA_GODOT_','DORA_BUILD_'))};env.update(DORA_GODOT_WINDOWS_GL='1',DORA_GODOT_LIBRARY=str(a.runtime_package/m['library']),DORA_GODOT_GL_DIRECT=a.direct)
delivery.run_command([str(a.binary),'--asset',str(out/'host/assets')],out/'run.log',60,env=env,cwd=a.binary.parent)
counts=[]
for suffix in ('a','b','c'):
 im=Image.open(out/('1-'+suffix+'.png')).convert('RGB');counts.append(dict(size=im.size,colors=len(im.getcolors(im.width*im.height) or [])))
(out/'diagnostic.json').write_text(json.dumps(dict(cold_start=True,direct=a.direct,images=counts,render_output_present=all(x['colors']>50 for x in counts)),indent=2)+'\n')
print(json.dumps(counts))
