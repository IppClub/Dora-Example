#!/usr/bin/env python3
"""Reuse a candidate CI artifact for one Linux x64 Release A->B->A check."""
import argparse,hashlib,json,os,re,subprocess,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[3]/'Test/support'))
from godot_paths import ENGINE_ROOT,TEST_REPO
p=argparse.ArgumentParser(description=__doc__)
for n in ['artifact','output']:p.add_argument('--'+n,type=Path,required=True)
p.add_argument('--engine-sha',required=True);p.add_argument('--run-id',required=True)
a=p.parse_args();root=ENGINE_ROOT;artifact=a.artifact.resolve();out=a.output.resolve()
assert sys.platform.startswith('linux') and re.fullmatch('[0-9a-f]{40}',a.engine_sha) and a.run_id.isdigit()
assert not out.exists(),'Use a fresh output directory';out.mkdir(parents=True)
def sha(path):
 with Path(path).open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
def git(*args):return subprocess.check_output(['git',*args],cwd=TEST_REPO)
report={'passed':False,'scope':__doc__,'source_engine_sha':a.engine_sha,'source_run_id':a.run_id,'runtime_rebuilt':False,'host_rebuilt':False,'dynamic_cases':1}
try:
 assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip()==a.engine_sha
 receipt_path=artifact/'godot-runtime/ci-linux-release/verification.json'
 receipt=json.loads(receipt_path.read_text());assert receipt['passed'] and receipt['github']['GITHUB_SHA']==a.engine_sha and receipt['github']['GITHUB_RUN_ID']==a.run_id
 commands=receipt['application_compile_commands'];assert commands and all('-DNDEBUG' in c and re.search(r' -O(?:[123s]|fast)\b',c) for c in commands)
 binary=artifact/'linux/x86_64/release/Dora';library=artifact/'godot-linux/package/libdora_godot.so'
 for file,suffix in [(binary,'/build/linux/x86_64/release/Dora'),(library,'/build/godot-linux/package/libdora_godot.so')]:
  expected=[v for k,v in receipt['artifacts'].items() if k.endswith(suffix)];assert len(expected)==1 and sha(file)==expected[0],file
 # The small harness may be newer than the source run, but the actual scene,
 # controller and verifier must be identical to that run's resolved test tree.
 refs=set(re.findall(r'/build/tests/revisions/([0-9a-f]{40})/', '\n'.join(receipt['source_hashes'])))
 assert len(refs)==1,refs
 source_tests=refs.pop();harness_tests=git('rev-parse','HEAD').decode().strip()
 subprocess.run(['git','fetch','--depth=1','origin',source_tests],cwd=TEST_REPO,check=True,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
 paths=['Test/support/godot_paths.py','Test/Godot/paths.json','Test/Godot/tests/with_weston.py','Test/Godot/tests/run_project_boundary_linux.py','Test/Godot/tests/verify_project_boundary.py','Test/Godot/tests/project_switch/linux_boundary.lua',*[f'Test/Godot/tests/project/{n}' for n in ['main.gd','main.tscn','project.godot','state.gd']]]
 for name in paths:assert git('show',source_tests+':'+name)==(TEST_REPO/name).read_bytes(),name
 report.update(source_tests_sha=source_tests,harness_tests_sha=harness_tests,artifact_receipt_sha256=sha(receipt_path),host_sha256=sha(binary),runtime_sha256=sha(library),production_case_unchanged=True)
 binary.chmod(binary.stat().st_mode|0o111)
 env=os.environ.copy();env.update(DORA_ENGINE_ROOT=str(root),DORA_TEST_REPO=str(TEST_REPO),SDL_AUDIODRIVER='dummy',LIBGL_ALWAYS_SOFTWARE='1')
 case=out/'case'
 command=[sys.executable,str(TEST_REPO/'Test/Godot/tests/with_weston.py'),'--logs',str(out/'weston'),'--',sys.executable,str(TEST_REPO/'Test/Godot/tests/run_project_boundary_linux.py'),'--binary',str(binary),'--library',str(library),'--output',str(case)]
 with (out/'run.log').open('w') as log:subprocess.run(command,cwd=root,env=env,check=True,stdout=log,stderr=subprocess.STDOUT,timeout=300)
 result=json.loads((case/'verification.json').read_text());assert result['passed'] and result['captures']==5
 log=(case/'run.log').read_text();rows=re.findall(r'DORA_GODOT_GL_TRANSPORT phase=close mode=(\S+).*?blits=(\d+) direct_publications=(\d+)',log)
 assert len(rows)==3 and all(mode=='direct' and blits=='0' and int(frames)>0 for mode,blits,frames in rows),rows
 assert sha(binary)==report['host_sha256'] and sha(library)==report['runtime_sha256']
 report.update(passed=True,captures=5,renderer=result['godot_renderer'],case_report='case/verification.json',direct_targets=True,blits=0)
except Exception as error:report['error']=repr(error);raise
finally:(out/'verification.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
