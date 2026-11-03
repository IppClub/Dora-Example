"""Run against an already running local engine; no process/lock/permission changes."""
import argparse, json, subprocess, os, shutil, time
from pathlib import Path
p=argparse.ArgumentParser(); p.add_argument('--engine',required=True); p.add_argument('--assets',required=True); p.add_argument('--case',choices=['baseline','mixed','wide','recolor','fast','Failures','Jolt','Animation','LoaderFailure','Diagnostics','DiagnosticCompatibility']); args=p.parse_args()
root=Path(__file__).resolve().parents[2]; evidence=Path(__file__).resolve().parent/'evidence'; evidence.mkdir(exist_ok=True)
cmd=[str(Path(args.engine).resolve()),'--asset',str(Path(args.assets).resolve()),'cli']
env=os.environ.copy()
for key in list(env):
    if key.lower() in ('http_proxy','https_proxy','all_proxy','no_proxy'): env.pop(key)
for case in ([args.case] if args.case else ['baseline','mixed','wide','recolor','fast','Failures','Jolt','Animation','LoaderFailure','Diagnostics','DiagnosticCompatibility']):
    report=evidence/(case.lower()+'.json'); report.unlink(missing_ok=True)
    if case=='DiagnosticCompatibility':
        result=subprocess.run(cmd+['run','-p',str(root),'--entry',f'Test/Creation3D/{case}.lua'],env=env,text=True,capture_output=True,timeout=20)
        assert result.returncode==0,result.stdout+result.stderr
        deadline=time.monotonic()+120
        while not report.exists() and time.monotonic()<deadline: time.sleep(.25)
        subprocess.run(cmd+['stop'],env=env,text=True,capture_output=True,timeout=20)
        assert report.exists(),'corpus compatibility timed out; inspect compatibility-progress.json'
        data=json.loads(report.read_text());assert data['status']=='passed',data
        print(case,'PASS',len(data['checks']),'existing fixtures',flush=True)
        continue
    result=subprocess.run(cmd+['agent','preview','-p',str(root),'--entry',f'Test/Creation3D/{case}.lua','--capture-at',('9,10' if case in ('Animation','Diagnostics','DiagnosticCompatibility') else '3.5,4.5')],env=env,text=True,capture_output=True,timeout=45)
    (evidence/(case.lower()+'-preview.json')).write_text(result.stdout)
    if result.returncode: raise RuntimeError(result.stderr+result.stdout)
    preview=json.loads(result.stdout); assert preview.get('success'),preview
    assert report.exists(),f'{case}: no fresh report (inspect cli log)'
    data=json.loads(report.read_text()); assert data['status']=='passed',data
    # Preview paths are project-relative; retain writable-root fallback for older engines.
    doctor=subprocess.run(cmd+['doctor'],env=env,text=True,capture_output=True,check=True,timeout=15).stdout
    writable=next((line.split(': ',1)[1] for line in doctor.splitlines() if line.startswith('Writable path: ')),None)
    for i,frame in enumerate(preview.get('frames',[])):
        src=Path(frame['path']); src=src if src.is_absolute() else root/src
        if not src.exists() and writable: src=Path(writable)/frame['path']
        if src.exists(): shutil.copy2(src,evidence/f'{case.lower()}-{i+1}.png')
    print(case,'PASS',len(data.get('checks',[])),'checks',flush=True)

if not args.case:
    baseline=json.loads((evidence/'baseline.json').read_text())
    edits=[]
    for name,key in [('wide','roadWidth'),('recolor','houseColor'),('fast','speed')]:
        variant=json.loads((evidence/(name+'.json')).read_text())
        changed=[k for k in baseline['config'] if baseline['config'][k]!=variant['config'][k]]
        assert changed==[key],(name,changed)
        assert baseline['layout']==variant['layout'],'unrelated seeded layout changed'
        edits.append(dict(case=name,changedKeys=changed,actual=variant['actual'],layoutPreserved=True))
    (evidence/'edits.json').write_text(json.dumps({'status':'passed','checks':edits},indent=2)+'\n')
    print('single-parameter edits PASS',flush=True)
