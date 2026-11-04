#!/usr/bin/env python3
"""One serial cold/warm binary-cache pair. A source fallback never passes."""
import argparse,hashlib,json,re,struct,subprocess,sys
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__)
for n in ['sdk','apk','runtime-package','lifecycle-apk','output']:p.add_argument('--'+n,type=Path,required=True)
p.add_argument('--serial',required=True);p.add_argument('--owned-avd',required=True);p.add_argument('--probe',type=Path)
a=p.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False);adb=[str(a.sdk/'platform-tools/adb'),'-s',a.serial];package='org.ippclub.dorassr'
def command(*args):return subprocess.run([*adb,*args],capture_output=True,timeout=30)
def text(*args):
 r=command(*args);assert r.returncode==0,r.stderr;return r.stdout.decode().strip()
assert text('shell','getprop','ro.kernel.qemu')=='1' and a.owned_avd.startswith('DoraGodotRC1_')
assert text('emu','avd','name').splitlines()[0]==a.owned_avd
assert command('shell','pm','path',package).returncode!=0,'Cold case requires a fresh test installation; preserve or explicitly clean previous test data first'
report={'passed':False,'scope':__doc__,'buffers':3,'serial':a.serial,'avd':a.owned_avd,'cases':{},'cache_preserved':False}
try:
 for label in ['cold','warm']:
  cmd=[sys.executable,str(Path(__file__).with_name('run_ordinary_release.py')),'--sdk',str(a.sdk.resolve()),'--serial',a.serial,'--owned-avd',a.owned_avd,'--apk',str(a.apk.resolve()),'--runtime-package',str(a.runtime_package.resolve()),'--lifecycle-apk',str(a.lifecycle_apk.resolve()),'--output',str(out/label),'--buffers','3','--engine-readback','--cache-audit']
  with (out/(label+'.log')).open('w') as log:r=subprocess.run(cmd,stdout=log,stderr=subprocess.STDOUT,timeout=300)
  controller=json.loads((out/label/'files/controller.json').read_text());native_log=(out/label/'run.log').read_text(errors='replace')
  assert all(marker in native_log for marker in ['QA_ACTIVITY_DESTROYED','GodotInstance::stop()','destroy: Logger.']), 'Native cleanup incomplete'
  report['cases'][label]={'strict_passed':r.returncode==0,'exit_code':r.returncode,'before':controller['shader_cache_before'],'after':controller['shader_cache_after'],'native_shutdown':True,'initial_pid':controller['initial_pid']}
  # Verification can fail after Activity.finish. Stop only the remaining Java
  # cache process after retaining native shutdown and strict failure evidence.
  assert command('shell','am','force-stop',package).returncode==0
  state=out/label/'active-run.json';active=json.loads(state.read_text());active.update(state='finished',full_native_shutdown=True,strict_acceptance_passed=r.returncode==0);state.write_text(json.dumps(active,indent=2)+'\n')
  if label=='cold':
   assert r.returncode==0,'Cold startup failed; do not continue to warm startup'
   cold=report['cases']['cold'];assert not cold['before'] and cold['after'],'Cold cache must begin empty and write real files'
   records={}
   for name,digest in cold['after'].items():
    if not name.endswith('.cache'):continue
    prefix,relative=name.split('/',1);assert prefix in ('files','cache') and '..' not in relative.split('/') and re.fullmatch(r'[A-Za-z0-9_./-]+',relative)
    raw=command('exec-out','su','0','cat',f'/data/user/0/{package}/{prefix}/{relative}');assert raw.returncode==0,raw.stderr
    data=raw.stdout;assert hashlib.sha256(data).hexdigest()==digest and data[:4]==b'GLSC'
    saved=out/'cold-cache'/name;saved.parent.mkdir(parents=True,exist_ok=True);saved.write_bytes(data)
    version,variants=struct.unpack_from('<II',data,4);assert version==3 and 0<variants<1000
    at=12;entries=[]
    for _ in range(variants):
     count=struct.unpack_from('<I',data,at)[0];at+=4;assert count<10000
     for _ in range(count):
      key,size=struct.unpack_from('<QI',data,at);at+=12
      if size:
       fmt=struct.unpack_from('<I',data,at)[0];at+=4;assert at+size<=len(data);entries.append({'key':key,'bytes':size,'format':fmt});at+=size
    assert at==len(data) and entries,'Empty or malformed binary cache'
    records[name]={'sha256':digest,'binary_entries':entries}
   assert records,'No actual binary cache records'
   report['cold_binary_records']=records
   (out/'cold-binaries.json').write_text(json.dumps(records,indent=2)+'\n')
 warm=report['cases']['warm'];assert warm['before']==cold['after'],'Warm startup did not retain the exact cold cache'
 assert warm['initial_pid']!=cold['initial_pid'],'Warm case must be a new app process'
 report['cache_preserved']=True;report['passed']=warm['strict_passed']
 if not report['passed'] and a.probe:
  cmd=[sys.executable,str(Path(__file__).parents[1]/'verify_timing_cap.py'),str(out/'warm'),'--engine-readback','--android-execution','--buffers','3','--diagnose-android-shader-cache',str(a.probe.resolve())]
  with (out/'warm-diagnostic.log').open('w') as log:diagnosis=subprocess.run(cmd,stdout=log,stderr=subprocess.STDOUT,timeout=30)
  report['diagnostic_exit_code']=diagnosis.returncode
except Exception as e:report['error']=str(e);raise
finally:
 (out/'verification.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({'passed':report['passed'],'cache_preserved':report['cache_preserved'],'cases':{k:v['strict_passed'] for k,v in report['cases'].items()}},indent=2))
if not report['passed']:sys.exit(1)
