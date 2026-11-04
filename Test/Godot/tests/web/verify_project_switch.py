#!/usr/bin/env python3
"""Check actual Web source/PCK lifecycle, pixels, GPU readers and PCM evidence."""
import argparse,hashlib,json,re
from pathlib import Path
from PIL import Image,ImageChops,ImageStat
p=argparse.ArgumentParser(description=__doc__);p.add_argument('output',type=Path);p.add_argument('package',type=Path);a=p.parse_args()
(a.output/'verification.json').unlink(missing_ok=True)
r=json.loads((a.output/'execution.json').read_text());m=json.loads((a.package/'project-switch-source.json').read_text());n=3 if m['smoke'] else 5
assert r['passed'] and r['player']=={'passed':True,'projects':n,'captures':n*3},r
assert json.loads((a.package/'dora-web-features.json').read_text())['activeProfile']=='dora-preset'
manifest=json.loads((a.package/'godot/manifest.json').read_text())
for name,digest in manifest['artifacts'].items():assert hashlib.sha256((a.package/'godot'/name).read_bytes()).hexdigest()==digest,name
logs='\n'.join(r['evidence']['logs']);assert not re.search(r'ERROR:|\[error\]|BGFX LEAK:|C\+\+ objects leaks',logs),logs
assert not [e for e in r['evidence']['errors'] if not e.startswith('Blocking on the main thread is very dangerous')],r['evidence']['errors']
assert not any(re.search(r'GL_INVALID|INVALID_OPERATION|INVALID_VALUE|INVALID_ENUM',e) for e in r['evidence']['warnings'])
assert logs.count('GODOT_FACTORY begin')==1 and r['distinctHeaps']
transport=re.findall(r'DORA_GODOT_GL_TRANSPORT phase=close mode=(\S+).*?buffers=(\d+) size=(\d+x\d+) blits=(\d+) direct_publications=(\d+)',logs)
assert len(transport)==n and all(mode=='direct' and blits=='0' and int(frames)>60 for mode,buffers,size,blits,frames in transport),transport
ids=re.findall(r'DORA_GODOT_PROJECT_ID instance=(\d+) tree=(\d+)',logs)
assert len(ids)==n and len({i for i,t in ids})==1 and len({t for i,t in ids})==n,ids
clean=[tuple(map(int,x)) for x in re.findall(r'DORA_GODOT_PROJECT_CLEAN objects=(\d+) resources=(\d+) nodes=(\d+)',logs)]
assert len(clean)==n+(0 if m['smoke'] else 1) and all(resources==1 and nodes==0 for objects,resources,nodes in clean),clean
if not m['smoke']:
 clean=clean[:1]+clean[2:]
 assert clean[2]==clean[4] and clean[1]==clean[3],clean
 for marker in ['cancel-before-ready','failure-recovered','duplicate','repeated-notification']:assert 'DORA_SWITCH_EDGE '+marker+'=1' in logs
s=r['switching'];opens=[x for x in s['opens'] if x['success']]
assert len(opens)==n and all(x['state']==1 for x in opens),opens
assert len(s['closes'])==n and all(x['state']==2 and x['copyReleased'] for x in s['closes']),s['closes']
assert len(s['queries'])>=n and all(x==2 for x in s['queries']),s['queries']
assert all(x['copyReleased'] and x['state']==2 for x in s['opens'] if not x['success'])
for i,h in enumerate(s['hashes']):assert h['files']==({'game.pck':m['squash']} if i%2 else m['dodge']),(i,'Godot copied files differ')
metrics=r['audio'];assert not metrics['protocol_errors'] and not metrics['underruns'],metrics
assert len(metrics['sessions'])==n
cases=[]
for i,session in enumerate(metrics['sessions'],1):
 assert session['buffers']==[2,3,4,2,3][i-1] and session['bindings']>0,session
 assert session['begins']>60 and session['ends']==session['begins']+session['empty_ends'] and session['pending_at_close']==0,session
 produced,completed,errors,deferred=session['close_stats'];assert produced==completed and errors==0 and deferred==0,session
 assert session['nonzero_consumed']>1000 and session['audio_stats'][3]==0,session
 images=[Image.open(a.output/f'{i}-{c}.png').convert('RGB') for c in 'abc'];changes=[]
 for im in images:assert len(im.getcolors(im.width*im.height) or [])>50 and ImageStat.Stat(im).sum[0]>100000
 for first,second in zip(images,images[1:]):
  changed=sum(count for value,count in enumerate(ImageChops.difference(first,second).convert('L').histogram()) if value>10);assert changed>100,(i,changed);changes.append(changed)
 movement=None
 if i%2:
  centers=[]
  for im in images[:2]:
   points=[x for y in range(100,650) for x in range(400,880) if (lambda c:120<c[0]<195 and 85<c[1]<165 and 65<c[2]<165 and c[0]>c[1]+8 and c[2]>c[1]-30)(im.getpixel((x,y)))]
   assert len(points)>100,(i,'sprite missing');centers.append(sum(points)/len(points))
  movement=centers[1]-centers[0];assert movement>60,(i,centers)
 cases.append({'buffers':session['buffers'],'produced_frames':produced,'changes':changes,'movement':movement,'pcm_nonzero':session['nonzero_consumed'],'clean':clean[i-1]})
t=r['teardown'];assert not t['platform']['active'] and not t['disposeAgain'] and not t['imePresent'],t
if r.get('contextLoss'):assert r['contextLoss']['lost'] and r['contextLoss']['openRejected'] and not r['contextLoss']['active'],r['contextLoss']
else:assert t['state']=='stopped'
report={'passed':True,'browser':r['browser'],'renderer':r['renderer'],'projects':n,'captures':n*3,'single_instance':ids[0][0],'cases':cases,'source_revision':m['source_revision'],'package_artifacts':{name:hashlib.sha256((a.package/name).read_bytes()).hexdigest() for name in ['dora-player-runtime.js','dora-player-runtime.wasm','dora-player-runtime.data','dora-web-manifest.json','dora-web-features.json','godot/manifest.json']},'copied_files_released':True,'context_loss':r.get('contextLoss'),'scope':'Bounded actual official projects in default Release Web host; no arbitrary-project isolation or long-duration GPU memory claim'}
(a.output/'verification.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
