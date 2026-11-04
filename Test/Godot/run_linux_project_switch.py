#!/usr/bin/env python3
"""Serial Linux EGL acceptance: isolation fixtures, lifecycle edges, official 2D/3D source/PCK games."""
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'Test/support'))
from godot_paths import ENGINE_ROOT,TEST_REPO
import argparse,json,re,subprocess
import project_delivery as delivery
p=argparse.ArgumentParser(description=__doc__)
for key in ('godot','binary','asset-source','runtime-package','repository','output'):
    p.add_argument('--'+key,type=Path,required=True)
p.add_argument('--legacy-runtime-package',type=Path)
a=p.parse_args();assert sys.platform=='linux'
out=a.output.resolve();assert not out.exists(),'Use a fresh output directory';out.mkdir(parents=True)
base=TEST_REPO/'Test/Godot'
host=['--binary',str(a.binary.resolve()),'--asset-source',str(a.asset_source.resolve()),'--runtime-package',str(a.runtime_package.resolve())]
common=['--godot',str(a.godot.resolve()),*host]
cases=[('fixture','run_project_switch.py',common),
       ('edges','run_project_lifecycle_edges.py',common+['--project-a',str(out/'fixture/prepared-a/project'),
        '--project-b',str(out/'fixture/prepared-b/project')]+(['--legacy-runtime-package',str(a.legacy_runtime_package.resolve())] if a.legacy_runtime_package else [])),
       ('real','run_real_project_switch.py',common+['--repository',str(a.repository.resolve())])]
reports={}
for name,script,arguments in cases:
    command=[sys.executable,str(base/'tests/with_weston.py'),'--logs',str(out/('weston-'+name)),
             '--timeout','900','--',sys.executable,str(base/script),*arguments,'--output',str(out/name)]
    with (out/(name+'-driver.log')).open('w') as log:
        subprocess.run(command,cwd=ENGINE_ROOT,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=930)
    report=json.loads((out/name/'verification.json').read_text());assert report['passed'],report
    reports[name]=report
renderers={name:re.findall(r'OpenGL API ([^\n]+)',(out/name/'run.log').read_text()) for name in ('fixture','real')}
assert all(len(values)==1 for values in renderers.values()),renderers
report={'passed':True,'scope':__doc__,'serial':True,'renderers':renderers,'cases':reports}
delivery.write_json(out/'verification.json',report)
print(json.dumps(report,indent=2))
