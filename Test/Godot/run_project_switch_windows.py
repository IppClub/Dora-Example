#!/usr/bin/env python3
"""Windows x64 WGL lifecycle acceptance, with a targeted MSAA recheck mode."""
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'Test/support'))
from godot_paths import ENGINE_ROOT,TEST_REPO
import argparse,ctypes,json,os,re,struct,subprocess
from PIL import Image,ImageChops
import project_delivery as delivery
import project_switch_host as host
from project import lua_string
p=argparse.ArgumentParser(description=__doc__)
for key in ('binary','asset-source','runtime-package','project-a','project-b','output'):
    p.add_argument('--'+key,type=Path,required=True)
p.add_argument('--source-revision',required=True)
p.add_argument('--targeted-msaa','--targeted-3d',dest='targeted_msaa',action='store_true',help='Reverify only B→A→B after a 3D/MSAA fix; reuse the earlier edge-case evidence')
a=p.parse_args();assert sys.platform=='win32'
out=a.output.resolve();assert not out.exists(),'Use a fresh result directory';out.mkdir(parents=True)
binary=a.binary.resolve();runtime=a.runtime_package.resolve();project_a=a.project_a.resolve();project_b=a.project_b.resolve()
b=binary.read_bytes();assert struct.unpack_from('<H',b,struct.unpack_from('<I',b,60)[0]+4)[0]==0x8664
assert b'dora_godot_node_test_main' not in b,'Use an ordinary host'
manifest=json.loads((runtime/'manifest.json').read_text());assert manifest['graphics_backend']=='wgl';library=runtime/manifest['library']
subprocess.run([sys.executable,str(ENGINE_ROOT/'Tools/Godot/verify_package.py'),str(runtime),'--output',str(out/'package-integrity.json')],check=True)
class ProjectAPI(ctypes.Structure):
    _fields_=[('size',ctypes.c_uint32),('abi_version',ctypes.c_uint32),('get_state',ctypes.CFUNCTYPE(ctypes.c_uint32))]
module=ctypes.CDLL(str(library));get=module.dora_godot_get_project_api;get.argtypes=[ctypes.c_uint32,ctypes.POINTER(ProjectAPI)];get.restype=ctypes.c_int
table=ProjectAPI();table.size=ctypes.sizeof(table)
assert get(1,ctypes.byref(table)) and table.size>=ctypes.sizeof(table) and table.abi_version==1 and table.get_state()==2
(out/'preflight.json').write_text(json.dumps({'passed':True,'project_api':1,'state_before_start':2,'architecture':'x86_64'})+'\n')
before=(delivery.fingerprint(project_a),delivery.digest(project_b));artifacts={str(x):delivery.digest(x) for x in (binary,library)}
with (out/'prepare-host.log').open('w') as log:
    subprocess.run([sys.executable,str(ENGINE_ROOT/'Tools/Godot/project.py'),'run',str(project_b),'--binary',str(binary),'--asset-source',str(a.asset_source.resolve()),'--runtime-package',str(runtime),'--work-dir',str(out/'host'),'--no-run'],stdout=log,stderr=subprocess.STDOUT,check=True)
sequence=['pck-squash','dodge','pck-squash'] if a.targeted_msaa else ['dodge','pck-squash','dodge','pck-squash','dodge']
buffers=[3,4,2] if a.targeted_msaa else [2,3,4,2,3];count=len(sequence)
items=[{'name':n,'path':str(project_a if n=='dodge' else project_b),'width':480 if n=='dodge' else 960,'height':720 if n=='dodge' else 540,'buffers':buffers[i]} for i,n in enumerate(sequence)]
lua_items='{'+','.join('{'+','.join(k+'='+ (lua_string(v) if isinstance(v,str) else str(v)) for k,v in item.items())+'}' for item in items)+'}'
invalid=out/'invalid-project';invalid.mkdir();(invalid/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Rejected switch fixture"\n')
template=(TEST_REPO/'Test/Godot/tests/project_switch/real_player.lua').read_text()
startup=template.replace('@OUTPUT@',lua_string(str(out))).replace('@PROJECTS@',lua_items).replace('@MIN_TICKS@','300').replace('@MINIMAL_EDGES@','false' if a.targeted_msaa else 'true').replace('@INVALID@',lua_string(str(invalid)))
command,executed_binary,assets=host.install(out/'host',startup)
env={k:v for k,v in os.environ.items() if not k.startswith(('DORA_GODOT_','DORA_BUILD_'))}
env.update(DORA_GODOT_WINDOWS_GL='1',DORA_GODOT_LIBRARY=str(library))
delivery.run_command(command,out/'run.log',240,env=env,cwd=binary.parent)
state=json.loads((out/'player.json').read_text());assert state.get('passed') and state['projects']==count and state['captures']==3*count,state
log=(out/'run.log').read_text();host.verify_gl_transport(log,count)
errors=[line for line in log.splitlines() if 'ERROR:' in line or '[error]' in line]
assert (not errors if a.targeted_msaa else len(errors)==1 and errors[0].endswith('GodotNode: Godot project has no main scene')),errors
assert all(token not in log for token in ('BGFX LEAK:','C++ objects leaks','SCRIPT ERROR:','GodotPlayer callback:'))
for edge in (() if a.targeted_msaa else ('cancel-before-ready','failure-recovered','duplicate','repeated-notification')):assert 'DORA_SWITCH_EDGE '+edge+'=1' in log,edge
ids=re.findall(r'DORA_GODOT_PROJECT_ID instance=(\d+) tree=(\d+)',log)
assert len(ids)==count and len({i for i,t in ids})==1 and len({t for i,t in ids})==count,ids
assert len(re.findall(r'OpenGL API ',log))==1,'Renderer was restarted'
frames=list(map(int,re.findall(r'DORA_GODOT_GL_DIRECT completed frames=(\d+) blits=0',log)));assert len(frames)==count and min(frames)>=60,frames
readers=re.findall(r'GodotRuntime readers: buffers=(\d+), frames=(\d+), waits=(\d+), signals=(\d+), pending=(\d+), completed=(\d+), gpuErrors=(\d+)',log)
assert len(readers)==count and [int(r[0]) for r in readers]==buffers,readers
assert all(int(f)>0 and f==c and pending=='0' and errors=='0' and 0<int(w)<=int(s) for b,f,w,s,pending,c,errors in readers),readers
clients=re.findall(r'GodotRuntime client closed: produced=(\d+), completed=(\d+), gpuErrors=(\d+)',log)
assert len(clients)==count and all(int(p)>0 and p==c and e=='0' for p,c,e in clients),clients
audio=re.findall(r'GodotAudio drained: produced=\d+, consumed=\d+, nonzeroProduced=(\d+), nonzeroConsumed=(\d+), underrunFrames=(\d+)',log)
assert len(audio)==count and all(int(p)>1000 and int(c)>1000 and u=='0' for p,c,u in audio),audio
raw_clean=[tuple(map(int,x)) for x in re.findall(r'DORA_GODOT_PROJECT_CLEAN objects=(\d+) resources=(\d+) nodes=(\d+)',log)]
assert len(raw_clean)==count+(0 if a.targeted_msaa else 1) and all(n==0 for o,r,n in raw_clean),raw_clean
clean=raw_clean if a.targeted_msaa else raw_clean[:1]+raw_clean[2:]
assert (clean[0]==clean[2] if a.targeted_msaa else clean[2]==clean[4] and clean[1]==clean[3]),clean
cases=[]
for i,name in enumerate(sequence,1):
    images=[Image.open(out/f'{i}-{suffix}.png').convert('RGB') for suffix in ('a','b','c')]
    assert all(img.size==images[0].size and min(img.size)>=640 and len(img.getcolors(img.width*img.height) or [])>50 for img in images),(i,'blank or unexpected size')
    changes=[]
    for first,second in zip(images,images[1:]):
        count=sum(n for value,n in enumerate(ImageChops.difference(first,second).convert('L').histogram()) if value>10);assert count>100,(i,count);changes.append(count)
    movement=None
    if name=='dodge':
        centers=[]
        for img in images[:2]:
            xs=[];pix=img.load()
            scale=min(img.width/480,img.height/720)
            left=(img.width-480*scale)/2;top=(img.height-720*scale)/2
            for y in range(round(top+100*scale),round(top+650*scale)):
                for x in range(round(left),round(left+480*scale)):
                    r,g,b=pix[x,y]
                    if 120<r<195 and 85<g<165 and 65<b<165 and r>g+8 and b>g-30:xs.append(x)
            assert len(xs)>100,(i,'missing player');centers.append(sum(xs)/len(xs))
        movement=centers[1]-centers[0];assert movement>60,(i,centers)
    cases.append(dict(project=name,buffers=buffers[i-1],frames=frames[i-1],changed_pixels=changes,input_move_pixels=movement,nonzero_pcm_samples=int(audio[i-1][1]),post_unload_objects=clean[i-1][0],post_unload_resources=clean[i-1][1],post_unload_nodes=clean[i-1][2]))
assert before==(delivery.fingerprint(project_a),delivery.digest(project_b)),'Project inputs changed'
assert all(delivery.digest(Path(path))==sha for path,sha in artifacts.items()),'Execution artifacts changed'
report=dict(passed=True,scope=__doc__,environment='Windows 11 ARM VM, x64 application; WGL virtual GPU',source_revision=a.source_revision,artifacts=artifacts,sequence=sequence,single_libgodot_instance=ids[0][0],scene_trees=[t for i,t in ids],renderer=re.findall(r'OpenGL API ([^\n]+)',log),cases=cases,source_inputs_unchanged=True,captures=3*count,gpu_errors=0,gpu_pending=0,blits=0,audio_underrun_frames=0,edges=[] if a.targeted_msaa else ['cancel-before-ready','failure-recovered','duplicate','repeated-notification'],targeted_msaa=a.targeted_msaa,successful_dynamic_rounds=1)
delivery.write_json(out/'verification.json',report);print(json.dumps(report,indent=2))
