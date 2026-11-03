"""Cold A/B profile; no discarded warm-up frames, shader or asset changes."""
import argparse,json,os,subprocess
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--engine',required=True);p.add_argument('--assets',required=True);a=p.parse_args()
root=Path(__file__).resolve().parents[2];out=Path(__file__).resolve().parent/'evidence';request=out/'profile-request.json'
cmd=[str(Path(a.engine).resolve()),'--asset',str(Path(a.assets).resolve()),'cli','agent','preview','-p',str(root),'--entry','Test/Creation3D/ProfileRun.lua','--capture-at','4']
env={k:v for k,v in os.environ.items() if k.lower() not in ('http_proxy','https_proxy','all_proxy','no_proxy')}
results=[]
try:
 for mode in ('sync','async'):
  for i in range(1,4):
   name=f'cold-{mode}-{i}';trace=out/(name+'-trace.json');trace.unlink(missing_ok=True)
   request.write_text(json.dumps(dict(name=name,mode=mode)))
   r=subprocess.run(cmd,text=True,capture_output=True,env=env,timeout=30)
   (out/(name+'-preview.json')).write_text(r.stdout)
   assert r.returncode==0 and json.loads(r.stdout)['success'],r.stdout+r.stderr
   d=json.loads(trace.read_text());assert d['status']=='passed'
   frames=sorted(f['dtMs'] for f in d['frames'])
   row=dict(name=name,mode=mode,readyMs=d['readyMs'],createMs=d['createMs'],modelLoadMs=d['spans']['load']['ms'],frameP95Ms=frames[int(len(frames)*.95)-1],maxFrameMs=frames[-1],maxUploadCommandUs=max(f['uploadMaxUs'] for f in d['frames']))
   results.append(row);print(json.dumps(row),flush=True)
 assert max(r['maxFrameMs'] for r in results if r['mode']=='async')<100,'async cold load still stalls over 100ms'
 summary=dict(status='passed',scope='three cold runs per mode, all 150 frames from loading included; local Debug/Metal only',checks=results)
 (out/'performance-comparison.json').write_text(json.dumps(summary,indent=2)+'\n')
finally:
 request.unlink(missing_ok=True)
