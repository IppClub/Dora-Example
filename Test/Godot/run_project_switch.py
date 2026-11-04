#!/usr/bin/env python3
"""macOS / Linux default single-LibGodot project-switch acceptance, serial native runs."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[2]/'Test/support'))
from godot_paths import ENGINE_ROOT, TEST_REPO
import argparse
import json
import os
import re
import subprocess
from collections import Counter
from PIL import Image
import project_delivery as delivery
import project_switch_host as host
from project import lua_string

p=argparse.ArgumentParser(description=__doc__)
for name in ['godot','runtime-package','output']: p.add_argument('--'+name,type=Path,required=True)
host.add_arguments(p)
a=p.parse_args();host_args=host.arguments(a)
assert sys.platform in ('darwin','linux')
out=a.output.resolve();assert not out.exists(),'Use a fresh output directory';out.mkdir(parents=True)
fixture=TEST_REPO/'Test/Godot/tests/project_switch'
projects={}
for tag in ['a','b']:
    prepared=delivery.prepare(fixture/tag,out/('prepared-'+tag),str(a.godot.resolve()))
    projects[tag]=str(out/('prepared-'+tag)/'project')
    delivery.export_game(fixture/tag,out/('packed-'+tag),out/('export-'+tag),str(a.godot.resolve()),
        'dora.switch-'+tag,'0.1.0',None,None,'macOS' if sys.platform=='darwin' else 'Linux')
    projects['pck-'+tag]=str(out/('packed-'+tag)/'game.pck')
cli=ENGINE_ROOT/'Tools/Godot/project.py'
with (out/'prepare-host.log').open('w') as log:
    subprocess.run([sys.executable,str(cli),'run',projects['a'],'--godot',str(a.godot.resolve()),
        *host_args,'--runtime-package',str(a.runtime_package.resolve()),
        '--work-dir',str(out/'host'),'--no-run'],cwd=ENGINE_ROOT,stdout=log,stderr=subprocess.STDOUT,check=True)
sequence=['a','a','b','a','pck-b','pck-a','b']
items=[{'path':projects[name],'tag':name[-1].upper(),'buffers':2+i%3} for i,name in enumerate(sequence)]
lua_items='{'+','.join('{path='+lua_string(x['path'])+',tag='+lua_string(x['tag'])+',buffers='+str(x['buffers'])+'}' for x in items)+'}'
template=(fixture/'player.lua').read_text()
invalid=out/'invalid-project';invalid.mkdir();(invalid/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Invalid switch fixture"\n')
startup=template.replace('@MIN_TICKS@','180' if sys.platform=='linux' else '0').replace('@PROJECTS@',lua_items).replace('@OUTPUT@',lua_string(str(out))).replace('@INVALID@',lua_string(str(invalid)))
command,binary,assets=host.install(out/'host',startup)
manifest=json.loads((a.runtime_package/'manifest.json').read_text());library=a.runtime_package/manifest['library']
env={k:v for k,v in os.environ.items() if not k.startswith(('DORA_GODOT_','DORA_BUILD_'))}
env.update(DORA_GODOT_LIBRARY=str(library.resolve()))
delivery.run_command(command,out/'run.log',180,env=env,cwd=binary.parent)
state=json.loads((out/'player.json').read_text());assert state.get('passed') and state.get('rejected_project_recovered') and state.get('single_client_enforced'),state
log=(out/'run.log').read_text();host.verify_gl_transport(log,len(items))
assert 'SCRIPT ERROR:' not in log and 'BGFX LEAK:' not in log and 'C++ objects leaks' not in log
loaded=re.findall(r'DORA_GODOT_PROJECT_SWITCH loaded=([AB]) static=1 resource=([AB]) autoload=([AB])',log)
assert loaded==[(x['tag'],)*3 for x in items],loaded
unloaded=re.findall(r'DORA_GODOT_PROJECT_SWITCH unloaded=([AB]) frames=(\d+)',log)
assert len(unloaded)==len(items) and all(int(n)>25 for _,n in unloaded),unloaded
identities=re.findall(r'DORA_GODOT_PROJECT_ID instance=(\d+) tree=(\d+)',log)
assert len(identities)==len(items),identities
assert len({i for i,t in identities})==1,'LibGodot was recreated'
assert len({t for i,t in identities})==len(items),'SceneTree was reused'
frames=re.findall(r'DORA_GODOT_(?:METAL|GL)_DIRECT completed frames=(\d+) blits=0',log)
assert len(frames)==len(items) and all(int(n)>25 for n in frames),frames
readers=re.findall(r'GodotRuntime readers:.*frames=(\d+), waits=\d+, signals=\d+, pending=(\d+), completed=\d+, gpuErrors=(\d+)',log)
assert len(readers)==len(items)+(0 if sys.platform=='linux' else 1) and all(x[1:]==('0','0') for x in readers),readers
assert sum(int(x[0])>0 for x in readers)==len(items),readers
audio=re.findall(r'GodotAudio drained: produced=\d+, consumed=\d+, nonzeroProduced=(\d+), nonzeroConsumed=(\d+), underrunFrames=\d+',log)
assert len(audio)==len(items),audio
for item,(produced,consumed) in zip(items,audio):
    if item['tag']=='A': assert int(produced)>1000 and int(consumed)>1000,(item,produced,consumed)
    else: assert produced=='0' and consumed=='0',('Old audio survived',item,produced,consumed)
captures=[]
for i,item in enumerate(items,1):
    img=Image.open(out/(str(i)+'.png')).convert('RGB')
    colors=Counter(img.get_flattened_data() if hasattr(img,'get_flattened_data') else img.getdata())
    count=sum(n for (r,g,b),n in colors.items() if r>200 and g<50 and b<50) if item['tag']=='A' else sum(n for (r,g,b),n in colors.items() if r<50 and 40<g<90 and b>200)
    assert count/(img.width*img.height)>.85,(i,count,img.size)
    captures.append({'project':sequence[i-1],'buffers':item['buffers'],'pixels':count,'size':list(img.size),'frames':int(frames[i-1]),'nonzero_audio_samples':int(audio[i-1][1])})
report={'passed':True,'scope':__doc__,'runtime_sha256':delivery.digest(library),'experimental_environment_present':'DORA_GODOT_PROJECT_SWITCH' in env,
        'libgodot_instance':identities[0][0],'scene_trees':[t for _,t in identities],
        'rejected_project_recovered':True,'single_client_enforced':True,'sequence':sequence,'cases':captures,'gpu_errors':0,'gpu_pending':0,'blits':0}
delivery.write_json(out/'verification.json',report)
print(json.dumps(report,indent=2))
