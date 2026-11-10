#!/usr/bin/env python3
"""macOS / Linux default project switching, cancellation and legacy-runtime refusal; no fixture import."""
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'Test/support'))
from godot_paths import ENGINE_ROOT,TEST_REPO
import argparse,json,os,re,subprocess
import project_delivery as delivery
import project_switch_host as host
from project import lua_string
p=argparse.ArgumentParser(description=__doc__)
for key in ['runtime-package','project-a','project-b','output']:p.add_argument('--'+key,type=Path,required=True)
p.add_argument('--legacy-runtime-package',type=Path)
p.add_argument('--godot',default=os.getenv('DORA_GODOT_EDITOR','godot'))
host.add_arguments(p)
a=p.parse_args();host_args=host.arguments(a);out=a.output.resolve();assert not out.exists();out.mkdir(parents=True)
runtime=a.runtime_package.resolve();m=json.loads((runtime/'manifest.json').read_text());library=runtime/m['library'];reports=[]
for name in ['default','cancel']+(['legacy'] if a.legacy_runtime_package else []):
    case_runtime=a.legacy_runtime_package.resolve() if name=='legacy' else runtime
    case_manifest=json.loads((case_runtime/'manifest.json').read_text())
    case_library=case_runtime/case_manifest['library']
    work=out/name
    with (out/(name+'-prepare.log')).open('w') as log:
        subprocess.run([os.environ.get('DORA_XMAKE','xmake'), 'lua', str(ENGINE_ROOT/'Tools/Godot/project.lua'),'run',str(a.project_b.resolve()),
            *host_args,'--godot',a.godot,'--runtime-package',str(case_runtime),'--work-dir',str(work),'--no-run'],
            stdout=log,stderr=subprocess.STDOUT,check=True,cwd=ENGINE_ROOT)
    script=(TEST_REPO/f'Test/Godot/tests/project_switch/{name}_player.lua').read_text()
    script=script.replace('@A@',lua_string(str(a.project_a.resolve()))).replace('@B@',lua_string(str(a.project_b.resolve()))).replace('@STATE@',lua_string(str(work/'state.json')))
    command,binary,assets=host.install(work,script)
    env={k:v for k,v in os.environ.items() if not k.startswith(('DORA_GODOT_','DORA_BUILD_'))};env['DORA_GODOT_LIBRARY']=str(case_library)
    assert 'DORA_GODOT_PROJECT_SWITCH' not in env
    delivery.run_command(command,work/'run.log',45,env=env,cwd=binary.parent)
    state=json.loads((work/'state.json').read_text());assert state['passed'];log=(work/'run.log').read_text()
    assert 'GodotPlayer callback:' not in log and 'BGFX LEAK:' not in log and 'C++ objects leaks' not in log
    assert len(re.findall(r'DORA_GODOT_(?:METAL|GL)_DIRECT enabled',log))==(1 if name=='legacy' else 2)
    reports.append({'case':name,'runtime_sha256':delivery.digest(case_library),'experimental_environment_present':False,**state})
report={'passed':True,'scope':__doc__,'cases':reports,'runtime_sha256':delivery.digest(library)}
delivery.write_json(out/'verification.json',report);print(json.dumps(report,indent=2))
