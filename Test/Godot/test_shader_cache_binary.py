#!/usr/bin/env python3
"""Verify exact GL binary persistence, including a pre-fix negative control."""
import argparse,hashlib,json,shutil,subprocess,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'support'))
from godot_paths import ENGINE_ROOT
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);p.add_argument('--baseline-ref');a=p.parse_args();a.output.mkdir(parents=True,exist_ok=False)
relative='Source/3rdParty/Godot/drivers/gles3/shader_gles3.cpp';harness=(Path(__file__).parent/'tests/shader_cache_cleanup/save_harness.cpp').read_text();cxx=shutil.which('clang++') or shutil.which('c++');assert cxx
def run(name,source,negative=False):
 body=source[source.index('void ShaderGLES3::_save_to_cache('):source.index('void ShaderGLES3::_clear_version(')]
 cpp=a.output/(name+'.cpp');exe=a.output/name;cpp.write_text(harness.replace('// @PRODUCTION_SAVER@',body))
 b=subprocess.run([cxx,'-std=c++17','-Wall','-Wextra',str(cpp),'-o',str(exe)],capture_output=True,text=True);(a.output/(name+'-build.log')).write_text(b.stdout+b.stderr);assert b.returncode==0,b.stderr
 r=subprocess.run([str(exe)],capture_output=True,text=True);(a.output/(name+'-run.log')).write_text(r.stdout+r.stderr)
 assert (r.returncode!=0 and 'Persisted length differs from actual returned bytes' in r.stderr) if negative else (r.returncode==0 and 'PASS:' in r.stdout),r
 return {'source_sha256':hashlib.sha256(source.encode()).hexdigest(),'negative_control':negative,'exit_code':r.returncode,'stdout':r.stdout,'stderr':r.stderr}
report={'passed':True,'scope':__doc__,'current':run('current',(ENGINE_ROOT/relative).read_text())}
if a.baseline_ref:report['baseline']=run('baseline',subprocess.check_output(['git','show',a.baseline_ref+':'+relative],cwd=ENGINE_ROOT,text=True),True)
(a.output/'verification.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
