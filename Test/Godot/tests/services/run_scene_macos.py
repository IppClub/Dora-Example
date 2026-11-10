"""Real embedded static scene service: no external Godot or script execution."""
import argparse,pathlib,subprocess,sys,hashlib,json
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[3]/'support'))
from godot_paths import ENGINE_ROOT
from scene_fixture import make_fixture
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--runtime',type=pathlib.Path,required=True);p.add_argument('--output',type=pathlib.Path,required=True);a=p.parse_args()
out=a.output.resolve();assert not out.exists();out.mkdir(parents=True);project=out/'project';make_fixture(project)
original={str(f.relative_to(project)):hashlib.sha256(f.read_bytes()).hexdigest() for f in project.rglob('*') if f.is_file() and not f.is_symlink()}
binary=out/'scene-test';subprocess.run(['clang++','-std=c++17','-fobjc-arc','-I',str(ENGINE_ROOT/'Source/Godot'),str(pathlib.Path(__file__).with_name('scene_macos.mm')),'-framework','Foundation','-framework','Metal','-o',str(binary)],check=True)
r=subprocess.run([str(binary),str(a.runtime.resolve()),str(project)],text=True,capture_output=True,timeout=90);(out/'native.log').write_text(r.stdout+r.stderr)
assert r.returncode==0,(r.returncode,(r.stdout+r.stderr)[-5000:]);assert 'EMBEDDED_SCENE_QUERY_PASS' in r.stdout
reports=[json.loads(line) for line in r.stdout.splitlines() if line.startswith('{')];main=reports[0]
props={p['name']:p['value'] for p in main['nodes'][0]['properties']}
assert props['position']=={'type':'Vector2','value':'Vector2(10, 20)'}
assert props['text']['value']=='中文场景'
assert props['custom']['id']=='R_custom' and props['custom_array']['items'][0]['id']=='R_custom'
assert main['subresources'][0]['properties'][1]['value']['type']=='Dictionary'
assert any(not resource['exists'] and resource['path']=='res://missing.png' for resource in main['resources'])
assert any(r.get('truncated') and r.get('nodeCount')==201 for r in reports)
for name,digest in original.items():assert hashlib.sha256((project/name).read_bytes()).hexdigest()==digest,name
for name in ('SCRIPT_EXECUTED','RESOURCE_EXECUTED','AUTOLOAD_EXECUTED'):assert not (project/name).exists(),name
print('PASS: native nodes/properties/typed references/signals, inheritance/subtree/limits/errors, source preservation, no resource or script execution and active-project isolation')
