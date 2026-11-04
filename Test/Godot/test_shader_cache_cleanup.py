#!/usr/bin/env python3
"""Compile actual Godot cache methods against a deterministic GL failure driver.

Checks GL program ownership, not physical driver behavior or shader binary
compatibility. --baseline-ref verifies that the previous source leaks programs.
"""
import argparse,hashlib,json,shutil,subprocess,sys,tempfile
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'support'))
from godot_paths import ENGINE_ROOT
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--output',type=Path,required=True)
p.add_argument('--baseline-ref',help='Optional existing engine Git ref; its test must reproduce the leak')
p.add_argument('--cxx',default=shutil.which('clang++') or shutil.which('c++'))
a=p.parse_args();assert a.cxx,'A C++17 compiler is required';out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
relative='Source/3rdParty/Godot/drivers/gles3/shader_gles3.cpp'
harness=(Path(__file__).parent/'tests/shader_cache_cleanup/harness.cpp').read_text()
def methods(source):
 sections=[]
 for signature,following in [('bool ShaderGLES3::_load_from_cache(', 'void ShaderGLES3::_save_to_cache('),('void ShaderGLES3::_clear_version(', 'void ShaderGLES3::_initialize_version('),('void ShaderGLES3::_initialize_version(', 'void ShaderGLES3::version_set_code(')]:
  start=source.index(signature);end=source.index(following,start);sections.append(source[start:end])
 return '\n'.join(sections)
def run(label,source,negative=False):
 cpp=out/(label+'.cpp');binary=out/label;cpp.write_text(harness.replace('// @PRODUCTION_METHODS@',methods(source)))
 command=[a.cxx,'-std=c++17','-fno-exceptions','-Wall','-Wextra',str(cpp),'-o',str(binary)]
 built=subprocess.run(command,capture_output=True,text=True);(out/(label+'-build.log')).write_text(built.stdout+built.stderr);assert built.returncode==0,built.stderr
 result=subprocess.run([str(binary)],capture_output=True,text=True);(out/(label+'-run.log')).write_text(result.stdout+result.stderr)
 if negative:assert result.returncode!=0 and 'program(s) still live' in result.stderr,result
 else:assert result.returncode==0 and 'PASS: 513' in result.stdout,result
 return {'source_sha256':hashlib.sha256(source.encode()).hexdigest(),'compile_command':command,'exit_code':result.returncode,'negative_control':negative,'stdout':result.stdout,'stderr':result.stderr}
source=(ENGINE_ROOT/relative).read_text();report={'scope':__doc__,'current':run('current',source)}
if a.baseline_ref:
 old=subprocess.check_output(['git','show',a.baseline_ref+':'+relative],cwd=ENGINE_ROOT,text=True)
 report['baseline']=run('baseline',old,True);report['baseline_ref']=a.baseline_ref
report['passed']=True;(out/'verification.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
