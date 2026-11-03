#!/usr/bin/env python3
"""Audit real Web game pixels, both independent source copies and shutdown."""

# Resolve engine inputs separately from the external test checkout.
import sys as _test_sys
from pathlib import Path as _TestPath
_test_sys.path.insert(0, str(_TestPath(__file__).resolve().parents[4] / 'Test/support'))
from godot_paths import ENGINE_ROOT, TEST_REPO, test_path
import argparse,json,shutil,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'android'))
from verify_dodge_release import verify_case
p=argparse.ArgumentParser(description=__doc__);p.add_argument('results',type=Path);a=p.parse_args();out=a.results.resolve()
execution=json.loads((out/'execution.json').read_text());assert execution['passed'] and execution['dodge'] and execution['controller_frames']==625
assert execution['godot_init_config']=={'godotPoolSize':4,'canvasResizePolicy':0},execution['godot_init_config']
assert not execution['teardown']['state']['active'] and not execution['teardown']['dispose_again'] and not execution['teardown']['ime_present']
proof=json.loads((out/'dodge-evidence.json').read_text());expected=proof['metadata']['upstream_project_files'];assert proof['host']==proof['godot']==expected
files=out/'files';files.mkdir(exist_ok=True)
for f in out.glob('*.png'):shutil.copy2(f,files/f.name)
(files/'result.json').write_text(json.dumps(proof['result'])+'\n')
logs=execution['logs'];logs=[l for l in logs if not l.startswith('Blocking on the main thread is very dangerous')]
(out/'run.log').write_text('\n'.join(logs)+'\n')
report=verify_case(out,3,proof['metadata'],{'dodge':True,'project_sha256':proof['godot']},web_host=True)
report.update(browser=execution['browser'],browser_engine=execution['browser_engine'],renderer=execution['renderer'],teardown=execution['teardown'],artifacts=execution['artifacts'],source_files=len(expected),both_independent_heaps_source_unchanged=True,allowed_browser_diagnostics=[l for l in execution['logs'] if l.startswith('Blocking on the main thread is very dangerous')])
(out/'verification.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({'passed':True,'source_files':len(expected),'captures':report['captures'],'metrics':report['metrics']},indent=2))
