#!/usr/bin/env python3
"""Stage unchanged official source/PCK projects in the default Web host."""
import argparse,hashlib,importlib.util,json,os,shutil,subprocess,zipfile
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__)
for name in ('engine','source','editor','work','package','runtime'):p.add_argument('--'+name,type=Path,required=True)
p.add_argument('--smoke',action='store_true');a=p.parse_args()
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[3]/'support'))
os.environ['DORA_ENGINE_ROOT']=str(a.engine)
from godot_paths import ENGINE_ROOT
import project_delivery as delivery
w=a.work.resolve();w.mkdir(parents=True,exist_ok=True)
if not (w/'dodge/prepared.json').exists():delivery.prepare(a.source/'2d/dodge_the_creeps',w/'dodge',str(a.editor))
if not (w/'squash-package/game.pck').exists():delivery.export_game(a.source/'3d/squash_the_creeps',w/'squash-package',w/'squash',str(a.editor),'official-squash',platform='Web')
stage=w/('stage-smoke' if a.smoke else 'stage-main');stage.mkdir()
project=w/'dodge/project'
files={f.relative_to(project).as_posix():hashlib.sha256(f.read_bytes()).hexdigest() for f in project.rglob('*') if f.is_file() and ('.godot' not in f.parts or f.relative_to(project).as_posix().startswith('.godot/imported/') or f.name in ('global_script_class_cache.cfg','uid_cache.bin'))}
with zipfile.ZipFile(stage/'Dodge.zip','w',zipfile.ZIP_DEFLATED) as z:
 for name in files:z.write(project/name,name)
shutil.copy2(w/'squash-package/game.pck',stage/'Squash.pck')
metadata={'dodge':files,'squash':hashlib.sha256((stage/'Squash.pck').read_bytes()).hexdigest(),'source_revision':subprocess.check_output(['git','-C',str(a.source),'rev-parse','HEAD'],text=True).strip(),'smoke':a.smoke}
base=Path(__file__).parents[1]/'project_switch/real_player.lua'
items=[]
for name,buffers in zip(['dodge','squash','dodge','squash','dodge'][:3 if a.smoke else 5],[2,3,4,2,3]):
 items.append('{name="%s",path=work.."/%s%s",width=%d,height=%d,buffers=%d}'%(name,name,'/game.pck' if name=='squash' else '',480 if name=='dodge' else 960,720 if name=='dodge' else 540,buffers))
lua=base.read_text().replace('@OUTPUT@','work').replace('@PROJECTS@','{'+','.join(items)+'}').replace('@MIN_TICKS@','300').replace('@MINIMAL_EDGES@','false' if a.smoke else 'true').replace('@INVALID@','work.."/invalid"').replace('D.App:shutdown()','print("DORA_WEB_SWITCH_DONE")')
lua='''local Dora=require("Dora")
local work=Dora.Path(Dora.Content.writablePath,"godot-switch")
Dora.thread(function()
assert(Dora.Content:mkdir(work))
assert(Dora.Content:copy("/game/Dodge.zip",work.."/dodge.zip"))
assert(Dora.Content:unzipAsync(work.."/dodge.zip",work.."/dodge"))
assert(Dora.Content:mkdir(work.."/squash"))
assert(Dora.Content:copy("/game/Squash.pck",work.."/squash/game.pck"))
assert(Dora.Content:mkdir(work.."/invalid"))
assert(Dora.Content:save(work.."/invalid/project.godot",'config_version=5\\n[application]\\nconfig/name="Missing Scene"\\n'))
'''+lua+'\nend)\n'
(stage/'init.lua').write_text(lua)
env=os.environ.copy();env.update(DORA_WEB_GAME_PROFILE='core',DORA_WEB_EAGER_GAME_ASSETS='1')
subprocess.run(['node',str(a.engine/'Projects/xmake/tools/web/package_web_game.mjs'),str(stage),str(a.package.resolve()),'init.lua'],env=env,check=True)
shutil.copytree(a.runtime,a.package/'godot',dirs_exist_ok=True)
(a.package/'project-switch-source.json').write_text(json.dumps(metadata,indent=2)+'\n')
