#!/usr/bin/env python3
"""One serial real-project switching run in an ordinary Android arm64 Release.

Only task-owned DoraGodotRC1_* emulators are accepted. On failure retain the
live run and evidence for diagnosis; do not silently restart the application.
"""
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'support'))
from godot_paths import ENGINE_ROOT
import argparse,hashlib,json,re,subprocess,time,zipfile
from PIL import Image,ImageChops
import project_switch_host as host
sys.path.insert(0,str(ENGINE_ROOT/'Tools/Godot'))
from verify_package import verify
p=argparse.ArgumentParser(description=__doc__)
for key in ('sdk','apk','runtime-package','lifecycle-apk','assets-manifest','output'):p.add_argument('--'+key,type=Path,required=True)
p.add_argument('--serial',required=True);p.add_argument('--owned-avd',required=True)
p.add_argument('--verify-only',action='store_true',help='Recheck exported evidence without launching any process')
a=p.parse_args();out=a.output.resolve();metadata=json.loads(a.assets_manifest.read_text());buffers=[2,3,4,2,3]
sha=lambda b:hashlib.sha256(b).hexdigest()
adb=[str(a.sdk/'platform-tools/adb'),'-s',a.serial]
def call(args,**kw):return subprocess.run(adb+args,check=True,timeout=30,**kw)
def text(args):return subprocess.check_output(adb+args,timeout=30).decode(errors='replace').strip()
if not a.verify_only:
 assert not out.exists();out.mkdir(parents=True)
 assert a.owned_avd.startswith('DoraGodotRC1_')
 assert text(['shell','getprop','ro.kernel.qemu'])=='1'
 assert text(['emu','avd','name']).splitlines()[0]==a.owned_avd
 existing=subprocess.run(adb+['shell','pidof','org.ippclub.dorassr'],capture_output=True,timeout=30)
 assert existing.returncode==1 and not existing.stdout.strip(),'Inspect the existing application before starting'
 verify(a.runtime_package)
 manifest=json.loads((a.runtime_package/'manifest.json').read_text())
 badging=subprocess.check_output([str(a.sdk/'build-tools/34.0.0/aapt'),'dump','badging',str(a.apk)],text=True)
 assert "package: name='org.ippclub.dorassr'" in badging and 'application-debuggable' not in badging
 with zipfile.ZipFile(a.apk) as archive:
  assert len(archive.namelist())==len(set(archive.namelist()))
  native=archive.read('lib/arm64-v8a/libmain.so');assert b'dora_godot_node_test_main' not in native
  assert sha(archive.read('lib/arm64-v8a/libgodot_android.so'))==manifest['library_sha256']
  assert sha(archive.read('assets/Script/init.lua'))==metadata['startup_sha256']
  assert sha(archive.read('assets/GodotSwitchSquash.pck'))==metadata['pck_sha256']
  assert sha(archive.read('assets/GodotSwitchDodge.zip'))==metadata['archive_sha256']
  for rel in manifest['licenses']:assert sha(archive.read('assets/GodotRuntimeNotices/'+rel))==manifest['artifacts'][rel]
 artifacts={'apk_sha256':sha(a.apk.read_bytes()),'runtime_sha256':manifest['library_sha256'],'host_sha256':sha(native),'controller_sha256':sha(a.lifecycle_apk.read_bytes()),'startup_sha256':metadata['startup_sha256']}
 (out/'artifacts.json').write_text(json.dumps(artifacts,indent=2)+'\n')
 for name,apk in [('target',a.apk),('controller',a.lifecycle_apk)]:
  with (out/(name+'-install.log')).open('w') as log:call(['install','-r',str(apk.resolve())],stdout=log,stderr=subprocess.STDOUT)
 call(['shell','am','wait-for-broadcast-idle'],capture_output=True)
 cmd=adb+['shell','am','instrument','-w','-e','project_switch','1','org.dora.godotrc1.lifecycle/org.dora.godotrc1.ReleaseLifecycle']
 (out/'active-run.json').write_text(json.dumps({'serial':a.serial,'avd':a.owned_avd,'state':'starting','command':cmd})+'\n')
 with (out/'instrumentation.log').open('wb') as ilog:
  process=subprocess.Popen(cmd,stdout=ilog,stderr=subprocess.STDOUT)
  deadline=time.monotonic()+30;pid=''
  while time.monotonic()<deadline:
   probe=subprocess.run(adb+['shell','pidof','org.ippclub.dorassr'],capture_output=True,timeout=30);pid=probe.stdout.decode().strip()
   if re.fullmatch(r'\d+',pid):break
   assert process.poll() is None,'Controller stopped before target startup'
   time.sleep(.2)
  assert re.fullmatch(r'\d+',pid),'Target PID not observed'
  (out/'active-run.json').write_text(json.dumps({'serial':a.serial,'avd':a.owned_avd,'state':'running','pid':int(pid)})+'\n')
  with (out/'run.log').open('wb') as log:
   logger=subprocess.Popen(adb+['logcat','--pid='+pid,'-v','raw'],stdout=log,stderr=subprocess.STDOUT)
   try:
    assert process.wait(timeout=210)==0
    deadline=time.monotonic()+15
    while time.monotonic()<deadline:
     if 'destroy: Logger.' in (out/'run.log').read_text(errors='replace'):break
     time.sleep(.2)
    assert 'destroy: Logger.' in (out/'run.log').read_text(errors='replace'),'Native shutdown incomplete; inspect without relaunching'
   finally:logger.terminate();logger.wait(timeout=10)
 external='/sdcard/Android/media/org.ippclub.dorassr/dora-godot-evidence'
 files=out/'files';files.mkdir()
 listing=text(['shell','ls','-1',external]).splitlines()
 assert set(listing)=={'player.json','result.json','controller.json'}|{f'{i}-{c}.png' for i in range(1,6) for c in 'abc'},listing
 for name in listing:(files/name).write_bytes(subprocess.check_output(adb+['exec-out','cat',external+'/'+name],timeout=30))
 (out/'active-run.json').write_text(json.dumps({'serial':a.serial,'avd':a.owned_avd,'state':'native-shutdown-complete','pid':int(pid)})+'\n')
else:artifacts=json.loads((out/'artifacts.json').read_text())
files=out/'files';state=json.loads((files/'player.json').read_text());assert state=={'passed':True,'projects':5,'captures':15},state
controller=json.loads((files/'controller.json').read_text());assert controller['project_switch'] and controller['direct'] and controller['gl_policy']=='default-direct'
assert controller['initial_pid']==controller['final_pid'] and controller['initial_pid']>0
assert controller['project_sha256']['dodge']==metadata['source_files']
assert controller['project_sha256']['squash']=={'game.pck':metadata['pck_sha256']}
log=(out/'run.log').read_text(errors='replace');host.verify_gl_transport(log,5,force=True)
assert all(x in log for x in ['QA_ACTIVITY_DESTROYED','destroy: Logger.','OnGodotTerminating','DORA_ANDROID_SWITCH complete=true'])
for edge in ['cancel-before-ready','failure-recovered','duplicate','repeated-notification']:assert 'DORA_SWITCH_EDGE '+edge+'=1' in log,edge
warnings=[l for l in log.splitlines() if 'WARNING:' in l or '[warning]' in l]
# Match the existing ordinary Android Release functional acceptance policy.
# Keep cache warnings in the report; this does not close cache-clean acceptance.
assert all(l.endswith("[warning] failed to open a new controller! Couldn't find mapping for device (0)") or l=='WARNING: Failed to load cached shader, recompiling.' for l in warnings),warnings
errors=[l for l in log.splitlines() if re.search(r'ERROR:|\[error\]|Fatal signal|FATAL EXCEPTION|SCRIPT ERROR:|Leaked instance:|Orphan StringName:|BGFX LEAK:',l)]
assert len(errors)==1 and errors[0].endswith('GodotNode: Godot project has no main scene'),errors
ids=re.findall(r'DORA_GODOT_PROJECT_ID instance=(\d+) tree=(\d+)',log);assert len(ids)==5 and len({i for i,t in ids})==1 and len({t for i,t in ids})==5,ids
assert len(re.findall(r'OpenGL API ',log))==1
assert log.count('OnGodotTerminating')==1
frames=list(map(int,re.findall(r'DORA_GODOT_GL_DIRECT completed frames=(\d+) blits=0',log)));assert len(frames)==5 and min(frames)>=60,frames
readers=re.findall(r'GodotRuntime readers: buffers=(\d+), frames=(\d+), waits=(\d+), signals=(\d+), pending=(\d+), completed=(\d+), gpuErrors=(\d+)',log)
assert len(readers)==5 and [int(r[0]) for r in readers]==buffers,readers
assert all(int(f)>0 and f==c and pending=='0' and e=='0' and 0<int(w)<=int(s) for b,f,w,s,pending,c,e in readers),readers
clients=re.findall(r'GodotRuntime client closed: produced=(\d+), completed=(\d+), gpuErrors=(\d+)',log);assert len(clients)==5 and all(int(p)>0 and p==c and e=='0' for p,c,e in clients),clients
audio=re.findall(r'GodotAudio drained: produced=\d+, consumed=\d+, nonzeroProduced=(\d+), nonzeroConsumed=(\d+), underrunFrames=(\d+)',log);assert len(audio)==5 and all(int(p)>1000 and int(c)>1000 and u=='0' for p,c,u in audio),audio
clean=[tuple(map(int,x)) for x in re.findall(r'DORA_GODOT_PROJECT_CLEAN objects=(\d+) resources=(\d+) nodes=(\d+)',log)];assert len(clean)==6 and all(n==0 for o,r,n in clean),clean
clean=clean[:1]+clean[2:];assert clean[2]==clean[4] and clean[1]==clean[3],clean
cases=[]
for i in range(1,6):
 images=[Image.open(files/f'{i}-{c}.png').convert('RGB') for c in 'abc'];assert all(im.size==images[0].size and min(im.size)>=320 and len(im.getcolors(im.width*im.height) or [])>50 for im in images),(i,'blank or invalid image')
 changes=[]
 for first,second in zip(images,images[1:]):
  changed=sum(n for value,n in enumerate(ImageChops.difference(first,second).convert('L').histogram()) if value>10);assert changed>100,(i,changed);changes.append(changed)
 movement=None
 if i%2:
  centers=[]
  for im in images[:2]:
   scale=min(im.width/480,im.height/720);left=(im.width-480*scale)/2;top=(im.height-720*scale)/2;xs=[];pix=im.load()
   for y in range(round(top+100*scale),round(top+650*scale)):
    for x in range(round(left),round(left+480*scale)):
     r,g,b=pix[x,y]
     if 120<r<195 and 85<g<165 and 65<b<165 and r>g+8 and b>g-30:xs.append(x)
   assert len(xs)>100,(i,'missing player');centers.append(sum(xs)/len(xs))
  movement=centers[1]-centers[0];assert movement>60,(i,centers)
 cases.append({'project':'dodge-source' if i%2 else 'squash-pck','buffers':buffers[i-1],'frames':frames[i-1],'changed_pixels':changes,'input_move_pixels':movement,'nonzero_pcm_samples':int(audio[i-1][1]),'cleanup':clean[i-1]})
report={'passed':True,'scope':'One ordinary Android arm64 Release process on a task-owned emulator; not physical device acceptance.','source_revision':metadata['source_revision'],'artifacts':artifacts,'controller':controller,'instance':ids[0][0],'trees':[t for i,t in ids],'cases':cases,'captures':15,'renderer':re.findall(r'OpenGL API ([^\n]+)',log),'gpu_errors':0,'gpu_pending':0,'blits':0,'audio_underrun_frames':0,'inputs_unchanged':True,'successful_dynamic_rounds':1,'environment_warnings':warnings,'shader_cache_clean':not any('Failed to load cached shader' in line for line in warnings),'cache_clean_acceptance':'Separate open task; no cross-process warm-cache acceptance claimed.'}
(out/'verification.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
