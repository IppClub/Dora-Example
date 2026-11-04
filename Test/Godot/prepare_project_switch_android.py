#!/usr/bin/env python3
"""Prepare ordinary Android assets for one real-project switching acceptance."""
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'support'))
from godot_paths import ENGINE_ROOT,TEST_REPO
import argparse,hashlib,json,shutil,zipfile
p=argparse.ArgumentParser(description=__doc__)
for key in ('project-a','project-b','output'):p.add_argument('--'+key,type=Path,required=True)
p.add_argument('--source-revision',required=True)
a=p.parse_args();out=a.output.resolve();assert not out.exists()
shutil.copytree(ENGINE_ROOT/'Assets',out)
sha=lambda data:hashlib.sha256(data).hexdigest()
project=a.project_a.resolve();assert (project/'.godot/imported').is_dir()
source_files={};packed_files={}
with zipfile.ZipFile(out/'GodotSwitchDodge.zip','w',zipfile.ZIP_DEFLATED) as archive:
 for f in sorted(project.rglob('*')):
  if not f.is_file():continue
  rel=f.relative_to(project)
  if '.godot' in rel.parts and not (rel.parts[:2]==('.godot','imported') or rel.as_posix() in ('.godot/global_script_class_cache.cfg','.godot/uid_cache.bin','.godot/scene_groups_cache.cfg')):continue
  data=f.read_bytes();archive.writestr(rel.as_posix(),data);packed_files[rel.as_posix()]=sha(data)
  if '.godot' not in rel.parts:source_files[rel.as_posix()]=sha(data)
shutil.copy2(a.project_b,out/'GodotSwitchSquash.pck')
metadata={'source_revision':a.source_revision,'repository':'https://github.com/godotengine/godot-demo-projects','project_a':'2d/dodge_the_creeps','project_b':'3d/squash_the_creeps','source_files':source_files,'packed_source_files':packed_files,'pck_sha256':sha(a.project_b.read_bytes()),'archive_sha256':sha((out/'GodotSwitchDodge.zip').read_bytes())}
(out/'GodotSwitchInputs.json').write_text(json.dumps(metadata,indent=2)+'\n')
items=[]
for i,(name,buffers) in enumerate(zip(['dodge','pck-squash','dodge','pck-squash','dodge'],[2,3,4,2,3])):
 path='dodge' if name=='dodge' else 'squash/game.pck'
 items.append('{name='+json.dumps(name)+',path=D.Path(work,'+json.dumps(path)+'),width='+str(480 if name=='dodge' else 960)+',height='+str(720 if name=='dodge' else 540)+',buffers='+str(buffers)+'}')
template=(TEST_REPO/'Test/Godot/tests/project_switch/real_player.lua').read_text()
assert template.count('D.App:shutdown()')==2
template=template.replace('@OUTPUT@','work').replace('@PROJECTS@','{'+','.join(items)+'}').replace('@MIN_TICKS@','300').replace('@MINIMAL_EDGES@','true').replace('@INVALID@','D.Path(work,"invalid")').replace('D.App:shutdown()','finishAndroid()')
bootstrap='''local Dora=require("Dora")
local C,P=Dora.Content,Dora.Path
local work=P(C.writablePath,"godot-release")
local function finishAndroid()
 local report=assert(C:load(P(work,"player.json")))
 local ok=report:find('"passed":true',1,true)~=nil
 assert(C:save(P(work,"result.json"),'{"complete":'..tostring(ok)..',"buffers":3,"full":false,"project_switch":true}'))
 print("DORA_ANDROID_SWITCH complete="..tostring(ok))
end
assert(C:copy("GodotSwitchDodge.zip",P(work,"dodge.zip")))
C:mkdir(P(work,"squash"));C:mkdir(P(work,"invalid"))
assert(C:copy("GodotSwitchSquash.pck",P(work,"squash/game.pck")))
assert(C:save(P(work,"invalid/project.godot"),'config_version=5\\n[application]\\nconfig/name="Rejected switch fixture"\\n'))
return Dora.thread(function()
 assert(C:unzipAsync(P(work,"dodge.zip"),P(work,"dodge")))
'''
(out/'Script/init.lua').write_text(bootstrap+template+'\nend)\n')
metadata['startup_sha256']=sha((out/'Script/init.lua').read_bytes())
(out.parent/(out.name+'-manifest.json')).write_text(json.dumps(metadata,indent=2)+'\n')
print(out)
