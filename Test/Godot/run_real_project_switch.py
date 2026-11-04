#!/usr/bin/env python3
"""Serial macOS Metal / Linux EGL acceptance of GodotPlayer with untouched official 2D/3D games."""
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'Test/support'))
from godot_paths import ENGINE_ROOT, TEST_REPO
import argparse
import json
import os
import re
import subprocess
from PIL import Image,ImageChops,ImageStat
import project_delivery as delivery
import project_switch_host as host
from project import lua_string
p=argparse.ArgumentParser(description=__doc__)
for name in ['godot','runtime-package','repository','output']:p.add_argument('--'+name,type=Path,required=True)
host.add_arguments(p)
a=p.parse_args();host_args=host.arguments(a)
out=a.output.resolve();assert not out.exists(),'Use a fresh output';out.mkdir(parents=True)
repo=a.repository.resolve();editor=a.godot.resolve();runtime=a.runtime_package.resolve()
revision=subprocess.check_output(['git','-C',str(repo),'rev-parse','HEAD'],text=True).strip()
inputs={'dodge':repo/'2d/dodge_the_creeps','squash':repo/'3d/squash_the_creeps'}
before={name:delivery.fingerprint(path) for name,path in inputs.items()}
projects={}
for name,path in inputs.items():
    delivery.prepare(path,out/('prepared-'+name),str(editor))
    projects[name]=str(out/('prepared-'+name)/'project')
    delivery.export_game(path,out/('packed-'+name),out/('export-'+name),str(editor),'dora.official-'+name,'0.1.0',None,None,'macOS' if sys.platform=='darwin' else 'Linux')
    projects['pck-'+name]=str(out/('packed-'+name)/'game.pck')
cli=ENGINE_ROOT/'Tools/Godot/project.py'
with (out/'prepare-host.log').open('w') as log:
    subprocess.run([sys.executable,str(cli),'run',str(out/'packed-dodge'),*host_args,
        '--runtime-package',str(runtime),'--work-dir',str(out/'host'),'--no-run'],stdout=log,stderr=subprocess.STDOUT,check=True,cwd=ENGINE_ROOT)
sequence=['dodge','squash','pck-dodge','pck-squash']*2
items=[{'path':projects[name],'name':name,'width':480 if name.endswith('dodge') else 960,
        'height':720 if name.endswith('dodge') else 540,'buffers':2+i%3} for i,name in enumerate(sequence)]
lua_items='{'+','.join('{path='+lua_string(x['path'])+',name='+lua_string(x['name'])+',width='+str(x['width'])+',height='+str(x['height'])+',buffers='+str(x['buffers'])+'}' for x in items)+'}'
template=(TEST_REPO/'Test/Godot/tests/project_switch/real_player.lua').read_text()
command,binary,assets=host.install(out/'host',template.replace('@MINIMAL_EDGES@','false').replace('@INVALID@','""').replace('@MIN_TICKS@','300' if sys.platform=='linux' else '0').replace('@OUTPUT@',lua_string(str(out))).replace('@PROJECTS@',lua_items))
manifest=json.loads((runtime/'manifest.json').read_text());library=runtime/manifest['library']
env={k:v for k,v in os.environ.items() if not k.startswith(('DORA_GODOT_','DORA_BUILD_'))}
env.update(DORA_GODOT_LIBRARY=str(library))
delivery.run_command(command,out/'run.log',240,env=env,cwd=binary.parent)
state=json.loads((out/'player.json').read_text());assert state.get('passed') and state['captures']==24,state
log=(out/'run.log').read_text();host.verify_gl_transport(log,8);assert 'ERROR:' not in log and '[error]' not in log and 'BGFX LEAK:' not in log and 'C++ objects leaks' not in log
ids=re.findall(r'DORA_GODOT_PROJECT_ID instance=(\d+) tree=(\d+)',log)
assert len(ids)==8 and len({i for i,t in ids})==1 and len({t for i,t in ids})==8,ids
frames=re.findall(r'DORA_GODOT_(?:METAL|GL)_DIRECT completed frames=(\d+) blits=0',log)
assert len(frames)==8 and all(int(n)>=60 for n in frames),frames
readers=re.findall(r'GodotRuntime readers:.*pending=(\d+), completed=\d+, gpuErrors=(\d+)',log)
assert len(readers)==8 and all(x==('0','0') for x in readers),readers
audio=re.findall(r'GodotAudio drained: produced=\d+, consumed=\d+, nonzeroProduced=(\d+), nonzeroConsumed=(\d+), underrunFrames=(\d+)',log)
assert len(audio)==8 and all(int(p)>1000 and int(c)>1000 for p,c,u in audio),audio
clean=[tuple(map(int,x)) for x in re.findall(r'DORA_GODOT_PROJECT_CLEAN objects=(\d+) resources=(\d+) nodes=(\d+)',log)]
assert len(clean)==8 and all(nodes==0 for objects,resources,nodes in clean),clean
# The first material/theme loads may warm persistent engine caches. Repeated
# visits to the same project after warmup must not grow ObjectDB/ResourceCache.
assert clean[4]==clean[6] and clean[5]==clean[7],('Unstable post-unload objects/resources',clean)
cases=[]
for i,name in enumerate(sequence,1):
    images=[Image.open(out/(str(i)+'-'+suffix+'.png')).convert('RGB') for suffix in ['a','b','c']]
    assert all(ImageStat.Stat(img).sum[0]>100000 for img in images),(name,'blank')
    colors=[len(img.getcolors(img.width*img.height) or []) for img in images]
    assert min(colors)>50,(name,colors)
    changes=[]
    for first,second in zip(images,images[1:]):
        diff=ImageChops.difference(first,second).convert('L');changed=sum(n for value,n in enumerate(diff.histogram()) if value>10)
        assert changed>100,(name,'no dynamic image',changed)
        changes.append(changed)
    movement = None
    if name.endswith('dodge'):
        centers=[]
        for img in images[:2]:
            points=[]
            pix=img.load()
            for y in range(100,650):
                for x in range(400,880):
                    r,g,b=pix[x,y]
                    if 120<r<195 and 85<g<165 and 65<b<165 and r>g+8 and b>g-30:points.append(x)
            assert len(points)>100,('Player sprite missing',i,len(points))
            centers.append(sum(points)/len(points))
        movement=centers[1]-centers[0]
        assert movement>60,('Public D key did not move the 2D player',i,centers)
    cases.append({'project':name,'buffers':items[i-1]['buffers'],'frames':int(frames[i-1]),'changed_pixels':changes,'public_input_move_pixels':movement,
        'nonzero_audio_samples':int(audio[i-1][1]),'audio_underrun_frames':int(audio[i-1][2]),
        'post_unload_objects':clean[i-1][0],'post_unload_resources':clean[i-1][1],'post_unload_nodes':clean[i-1][2]})
for name,path in inputs.items():assert delivery.fingerprint(path)==before[name],('Author project changed',name)
report={'passed':True,'scope':__doc__,'source_revision':revision,'sources_unchanged':True,
        'host_sha256':delivery.digest(binary),'runtime_sha256':delivery.digest(library),'experimental_environment_present':'DORA_GODOT_PROJECT_SWITCH' in env,
        'controller_sha256':delivery.digest(assets/'Script/Lib/GodotPlayer.lua'),
        'single_libgodot_instance':ids[0][0],'scene_trees':[t for i,t in ids],'cases':cases,
        'gpu_errors':0,'gpu_pending':0,'blits':0,'captures':24,'source_and_pck':True}
delivery.write_json(out/'verification.json',report)
print(json.dumps(report,indent=2))
